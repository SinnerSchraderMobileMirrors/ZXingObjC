/*
 * Copyright 2013 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXBitMatrix.h"
#import "ZXDecoderResult.h"
#import "ZXPDF417BarcodeMatrix.h"
#import "ZXPDF417BarcodeMetadata.h"
#import "ZXPDF417BoundingBox.h"
#import "ZXPDF417Codeword.h"
#import "ZXPDF417CodewordDecoder.h"
#import "ZXPDF417Common.h"
#import "ZXPDF417DecodedBitStreamParser.h"
#import "ZXPDF417DetectionResult.h"
#import "ZXPDF417DetectionResultRowIndicatorColumn.h"
#import "ZXPDF417ECErrorCorrection.h"
#import "ZXPDF417ScanningDecoder.h"
#import "ZXResultPoint.h"

const int ZXPDF417_ROW_HEIGHT_SKEW = 2;
//  const int ZXPDF417_STOP_PATTERN_VALUE = 130324;
const int ZXPDF417_CODEWORD_SKEW_SIZE = 2;

const int ZXPDF417_MAX_ERRORS = 3;
const int ZXPDF417_MAX_EC_CODEWORDS = 512;
static ZXPDF417ECErrorCorrection *errorCorrection;

@implementation ZXPDF417ScanningDecoder

+ (void)initialize {
  errorCorrection = [[ZXPDF417ECErrorCorrection alloc] init];
}

// TODO don't pass in minCodewordWidth and maxCodewordWidth, pass in barcode columns for start and stop pattern
// columns. That way width can be deducted from the pattern column.
// This approach also allows to detect more details about the barcode, e.g. if a bar type (white or black) is wider
// than it should be. This can happen if the scanner used a bad blackpoint.
+ (ZXDecoderResult *)decode:(ZXBitMatrix *)image
               imageTopLeft:(ZXResultPoint *)imageTopLeft
            imageBottomLeft:(ZXResultPoint *)imageBottomLeft
              imageTopRight:(ZXResultPoint *)imageTopRight
           imageBottomRight:(ZXResultPoint *)imageBottomRight
           minCodewordWidth:(int)minCodewordWidth
           maxCodewordWidth:(int)maxCodewordWidth {
  ZXPDF417BoundingBox *boundingBox = [[ZXPDF417BoundingBox alloc] initWithImage:image topLeft:imageTopLeft bottomLeft:imageBottomLeft topRight:imageTopRight bottomRight:imageBottomRight];
  ZXPDF417DetectionResultRowIndicatorColumn *leftRowIndicatorColumn;
  ZXPDF417DetectionResultRowIndicatorColumn *rightRowIndicatorColumn;
  ZXPDF417DetectionResult *detectionResult;
  BOOL again = YES;
  while (again) {
    again = NO;
    if (imageTopLeft) {
      leftRowIndicatorColumn = [self rowIndicatorColumn:image boundingBox:boundingBox startPoint:imageTopLeft leftToRight:YES
                                       minCodewordWidth:minCodewordWidth maxCodewordWidth:maxCodewordWidth];
      [leftRowIndicatorColumn setRowNumbers];
    }
    if (imageTopRight) {
      rightRowIndicatorColumn = [self rowIndicatorColumn:image boundingBox:boundingBox startPoint:imageTopRight leftToRight:NO
                                        minCodewordWidth:minCodewordWidth maxCodewordWidth:maxCodewordWidth];
      [rightRowIndicatorColumn setRowNumbers];
    }
    detectionResult = [self merge:leftRowIndicatorColumn rightRowIndicatorColumn:rightRowIndicatorColumn];
    if (!detectionResult) {
      return nil;
    }
    if ([detectionResult boundingBox].minY < boundingBox.minY ||
        [detectionResult boundingBox].maxY > boundingBox.maxY) {
      boundingBox = [detectionResult boundingBox];
      again = YES;
    }
  }
  int maxBarcodeColumn = detectionResult.barcodeColumnCount + 1;
  [detectionResult setDetectionResultColumn:0 detectionResultColumn:leftRowIndicatorColumn];
  [detectionResult setDetectionResultColumn:maxBarcodeColumn detectionResultColumn:rightRowIndicatorColumn];

  BOOL leftToRight = leftRowIndicatorColumn != nil;
  for (int barcodeColumnCount = 1; barcodeColumnCount <= maxBarcodeColumn; barcodeColumnCount++) {
    int barcodeColumn = leftToRight ? barcodeColumnCount : maxBarcodeColumn - barcodeColumnCount;
    if ([detectionResult detectionResultColumn:barcodeColumn]) {
      // This will be the case for the opposite row indicator column, which doesn't need to be decoded again.
      continue;
    }
    ZXPDF417DetectionResultColumn *detectionResultColumn;
    if (barcodeColumn == 0 || barcodeColumn == maxBarcodeColumn) {
      detectionResultColumn = [[ZXPDF417DetectionResultRowIndicatorColumn alloc] initWithBoundingBox:boundingBox isLeft:barcodeColumn == 0];
    } else {
      detectionResultColumn = [[ZXPDF417DetectionResultColumn alloc] initWithBoundingBox:boundingBox];
    }
    [detectionResult setDetectionResultColumn:barcodeColumn detectionResultColumn:detectionResultColumn];
    int startColumn = -1;
    int previousStartColumn = startColumn;
    // TODO start at a row for which we know the start position, then detect upwards and downwards from there.
    for (int imageRow = boundingBox.minY; imageRow < boundingBox.maxY; imageRow++) {
      startColumn = [self startColumn:detectionResult barcodeColumn:barcodeColumn imageRow:imageRow leftToRight:leftToRight];
      if (startColumn < 0 || startColumn > boundingBox.maxX) {
        if (previousStartColumn == -1) {
          continue;
        }
        startColumn = previousStartColumn;
      }
      ZXPDF417Codeword *codeword = [self detectCodeword:image minColumn:boundingBox.minX maxColumn:boundingBox.maxX leftToRight:leftToRight
                                            startColumn:startColumn imageRow:imageRow minCodewordWidth:minCodewordWidth maxCodewordWidth:maxCodewordWidth];
      if (codeword) {
        [detectionResultColumn setCodeword:imageRow codeword:codeword];
        previousStartColumn = startColumn;
        minCodewordWidth = MIN(minCodewordWidth, codeword.width);
        maxCodewordWidth = MAX(maxCodewordWidth, codeword.width);
      }
    }
  }
  return [self createDecoderResult:detectionResult];
}

+ (ZXPDF417DetectionResult *)merge:(ZXPDF417DetectionResultRowIndicatorColumn *)leftRowIndicatorColumn
           rightRowIndicatorColumn:(ZXPDF417DetectionResultRowIndicatorColumn *)rightRowIndicatorColumn {
  if (!leftRowIndicatorColumn && !rightRowIndicatorColumn) {
    return nil;
  }
  ZXPDF417BarcodeMetadata *barcodeMetadata = [self barcodeMetadata:leftRowIndicatorColumn rightRowIndicatorColumn:rightRowIndicatorColumn];
  if (!barcodeMetadata) {
    return nil;
  }
  ZXPDF417BoundingBox *boundingBox = [self boundingBox:leftRowIndicatorColumn rightRowIndicatorColumn:rightRowIndicatorColumn];
  return [[ZXPDF417DetectionResult alloc] initWithBarcodeMetadata:barcodeMetadata boundingBox:boundingBox];
}

+ (ZXPDF417BoundingBox *)boundingBox:(ZXPDF417DetectionResultRowIndicatorColumn *)leftRowIndicatorColumn
             rightRowIndicatorColumn:(ZXPDF417DetectionResultRowIndicatorColumn *)rightRowIndicatorColumn {
  ZXPDF417BoundingBox *box1 = [self adjustBoundingBox:leftRowIndicatorColumn];
  ZXPDF417BoundingBox *box2 = [self adjustBoundingBox:rightRowIndicatorColumn];

  return [ZXPDF417BoundingBox mergeLeftBox:box1 rightBox:box2];
}

+ (ZXPDF417BoundingBox *)adjustBoundingBox:(ZXPDF417DetectionResultRowIndicatorColumn *)rowIndicatorColumn {
  if (!rowIndicatorColumn) {
    return nil;
  }
  NSArray *rowHeights = [rowIndicatorColumn rowHeights];
  int maxRowHeight = [self max:rowHeights];
  int missingStartRows = 0;
  for (NSNumber *rowHeight in rowHeights) {
    if ([rowHeight intValue] < maxRowHeight - ZXPDF417_ROW_HEIGHT_SKEW) {
      missingStartRows++;
    } else {
      break;
    }
  }
  int missingEndRows = 0;
  for (int row = (int)[rowHeights count] - 1; row >= 0; row--) {
    if ([rowHeights[row] intValue] < maxRowHeight - ZXPDF417_ROW_HEIGHT_SKEW) {
      missingEndRows++;
    } else {
      break;
    }
  }
  [rowIndicatorColumn.boundingBox addMissingRows:missingStartRows * maxRowHeight missingEndRows:missingEndRows * maxRowHeight
                                          isLeft:rowIndicatorColumn.isLeft];
  return rowIndicatorColumn.boundingBox;
}

+ (int)max:(NSArray *)values {
  int maxValue = -1;
  for (NSNumber *value in values) {
    maxValue = MAX(maxValue, [value intValue]);
  }
  return maxValue;
}

+ (ZXPDF417BarcodeMetadata *)barcodeMetadata:(ZXPDF417DetectionResultRowIndicatorColumn *)leftRowIndicatorColumn
                     rightRowIndicatorColumn:(ZXPDF417DetectionResultRowIndicatorColumn *)rightRowIndicatorColumn {
  if (!leftRowIndicatorColumn || !leftRowIndicatorColumn.barcodeMetadata) {
    return rightRowIndicatorColumn ? rightRowIndicatorColumn.barcodeMetadata : nil;
  }
  if (!rightRowIndicatorColumn || !rightRowIndicatorColumn.barcodeMetadata) {
    return leftRowIndicatorColumn ? leftRowIndicatorColumn.barcodeMetadata : nil;
  }
  ZXPDF417BarcodeMetadata *leftBarcodeMetadata = leftRowIndicatorColumn.barcodeMetadata;
  ZXPDF417BarcodeMetadata *rightBarcodeMetadata = rightRowIndicatorColumn.barcodeMetadata;

  if (leftBarcodeMetadata.columnCount != rightBarcodeMetadata.columnCount &&
      leftBarcodeMetadata.errorCorrectionLevel != rightBarcodeMetadata.errorCorrectionLevel &&
      leftBarcodeMetadata.rowCount != rightBarcodeMetadata.rowCount) {
    return nil;
  }
  return leftBarcodeMetadata;
}

+ (ZXPDF417DetectionResultRowIndicatorColumn *)rowIndicatorColumn:(ZXBitMatrix *)image
                                                      boundingBox:(ZXPDF417BoundingBox *)boundingBox
                                                       startPoint:(ZXResultPoint *)startPoint
                                                      leftToRight:(BOOL)leftToRight
                                                 minCodewordWidth:(int)minCodewordWidth
                                                 maxCodewordWidth:(int)maxCodewordWidth {
  ZXPDF417DetectionResultRowIndicatorColumn *rowIndicatorColumn = [[ZXPDF417DetectionResultRowIndicatorColumn alloc] initWithBoundingBox:boundingBox
                                                                                                                                  isLeft:leftToRight];
  for (int i = 0; i < 2; i++) {
    int increment = i == 0 ? 1 : -1;
    int startColumn = (int) startPoint.x;
    for (int imageRow = (int) startPoint.y; imageRow <= boundingBox.maxY &&
        imageRow >= boundingBox.minY; imageRow += increment) {
      ZXPDF417Codeword *codeword = [self detectCodeword:image minColumn:0 maxColumn:image.width leftToRight:leftToRight startColumn:startColumn imageRow:imageRow
                                       minCodewordWidth:minCodewordWidth maxCodewordWidth:maxCodewordWidth];
      if (codeword) {
        [rowIndicatorColumn setCodeword:imageRow codeword:codeword];
        if (leftToRight) {
          startColumn = codeword.startX;
        } else {
          startColumn = codeword.endX;
        }
      }
    }
  }
  return rowIndicatorColumn;
}

+ (ZXDecoderResult *)createDecoderResult:(ZXPDF417DetectionResult *)detectionResult {
  ZXPDF417BarcodeMatrix *barcodeMatrix = [self createBarcodeMatrix:detectionResult];
  NSNumber *numberOfCodewords = [barcodeMatrix value:0 column:1];
  int calculatedNumberOfCodewords = detectionResult.barcodeColumnCount * detectionResult.barcodeRowCount -
    [self numberOfECCodeWords:detectionResult.barcodeECLevel];
  if (!numberOfCodewords) {
    if (calculatedNumberOfCodewords < 1 || calculatedNumberOfCodewords > ZXPDF417_MAX_CODEWORDS_IN_BARCODE) {
      return nil;
    }
    [barcodeMatrix setValue:0 column:1 value:calculatedNumberOfCodewords];
  }
  NSMutableArray *erasures = [NSMutableArray array];
  NSMutableArray *codewords = [NSMutableArray array];
  for (int i = 0; i < detectionResult.barcodeRowCount * detectionResult.barcodeColumnCount; i++) {
    [codewords addObject:@0];
  }

  for (int row = 0; row < detectionResult.barcodeRowCount; row++) {
    for (int column = 0; column < detectionResult.barcodeColumnCount; column++) {
      NSNumber *codeword = [barcodeMatrix value:row column:column + 1];
      if (!codeword) {
        [erasures addObject:@(row * detectionResult.barcodeColumnCount + column)];
      } else {
        codewords[row * detectionResult.barcodeColumnCount + column] = codeword;
      }
    }
  }
  return [self decodeCodewords:codewords ecLevel:detectionResult.barcodeECLevel erasures:erasures];
}

+ (ZXPDF417BarcodeMatrix *)createBarcodeMatrix:(ZXPDF417DetectionResult *)detectionResult {
  ZXPDF417BarcodeMatrix *barcodeMatrix = [[ZXPDF417BarcodeMatrix alloc] init];

  int column = -1;
  for (ZXPDF417DetectionResultColumn *detectionResultColumn in detectionResult.detectionResultColumns) {
    column++;
    if ((id)detectionResultColumn == [NSNull null]) {
      continue;
    }
    for (ZXPDF417Codeword *codeword in detectionResultColumn.codewords) {
      if ((id)codeword == [NSNull null]) {
        continue;
      }
      [barcodeMatrix setValue:codeword.rowNumber column:column value:codeword.value];
    }
  }
  return barcodeMatrix;
}

+ (BOOL)isValidBarcodeColumn:(ZXPDF417DetectionResult *)detectionResult barcodeColumn:(int)barcodeColumn {
  return barcodeColumn >= 0 && barcodeColumn <= detectionResult.barcodeColumnCount + 1;
}

+ (int)startColumn:(ZXPDF417DetectionResult *)detectionResult barcodeColumn:(int)barcodeColumn imageRow:(int)imageRow leftToRight:(BOOL)leftToRight {
  int offset = leftToRight ? 1 : -1;
  ZXPDF417Codeword *codeword;
  if ([self isValidBarcodeColumn:detectionResult barcodeColumn:barcodeColumn - offset]) {
    codeword = [[detectionResult detectionResultColumn:barcodeColumn - offset] codeword:imageRow];
  }
  if (codeword) {
    return leftToRight ? codeword.endX : codeword.startX;
  }
  codeword = [[detectionResult detectionResultColumn:barcodeColumn] codewordNearby:imageRow];
  if (codeword) {
    return leftToRight ? codeword.startX : codeword.endX;
  }
  if ([self isValidBarcodeColumn:detectionResult barcodeColumn:barcodeColumn - offset]) {
    codeword = [[detectionResult detectionResultColumn:barcodeColumn - offset] codewordNearby:imageRow];
  }
  if (codeword) {
    return leftToRight ? codeword.endX : codeword.startX;
  }
  int skippedColumns = 0;

  while ([self isValidBarcodeColumn:detectionResult barcodeColumn:barcodeColumn - offset]) {
    barcodeColumn -= offset;
    for (ZXPDF417Codeword *previousRowCodeword in [detectionResult detectionResultColumn:barcodeColumn].codewords) {
      if ((id)previousRowCodeword != [NSNull null]) {
        return (leftToRight ? previousRowCodeword.endX : previousRowCodeword.startX) + offset *
            skippedColumns * (previousRowCodeword.endX - previousRowCodeword.startX);
      }
    }
    skippedColumns++;
  }
  return leftToRight ? detectionResult.boundingBox.minX : detectionResult.boundingBox.maxX;
}

+ (ZXPDF417Codeword *)detectCodeword:(ZXBitMatrix *)image minColumn:(int)minColumn maxColumn:(int)maxColumn leftToRight:(BOOL)leftToRight
                         startColumn:(int)startColumn imageRow:(int)imageRow minCodewordWidth:(int)minCodewordWidth maxCodewordWidth:(int)maxCodewordWidth {
  startColumn = [self adjustCodewordStartColumn:image minColumn:minColumn maxColumn:maxColumn leftToRight:leftToRight codewordStartColumn:startColumn imageRow:imageRow];
  // we usually know fairly exact now how long a codeword is. We should provide minimum and maximum expected length
  // and try to adjust the read pixels, e.g. remove single pixel errors or try to cut off exceeding pixels.
  // min and maxCodewordWidth should not be used as they are calculated for the whole barcode an can be inaccurate
  // for the current position
  NSMutableArray *moduleBitCount = [self moduleBitCount:image minColumn:minColumn maxColumn:maxColumn leftToRight:leftToRight startColumn:startColumn imageRow:imageRow];
  if (!moduleBitCount) {
    return nil;
  }
  int endColumn;
  int codewordBitCount = [ZXPDF417Common bitCountSum:moduleBitCount];
  if (leftToRight) {
    endColumn = startColumn + codewordBitCount;
  } else {
    for (int i = 0; i < [moduleBitCount count] >> 1; i++) {
      int tmpCount = [moduleBitCount[i] intValue];
      moduleBitCount[i] = moduleBitCount[[moduleBitCount count] - 1 - i];
      moduleBitCount[[moduleBitCount count] - 1 - i] = @(tmpCount);
    }
    endColumn = startColumn;
    startColumn = endColumn - codewordBitCount;
  }
  // TODO implement check for width and correction of black and white bars
  // use start (and maybe stop pattern) to determine if blackbars are wider than white bars. If so, adjust.
  // should probably done only for codewords with a lot more than 17 bits. 
  // The following fixes 10-1.png, which has wide black bars and small white bars
  //    for (int i = 0; i < moduleBitCount.length; i++) {
  //      if (i % 2 == 0) {
  //        moduleBitCount[i]--;
  //      } else {
  //        moduleBitCount[i]++;
  //      }
  //    }

  // We could also use the width of surrounding codewords for more accurate results, but this seems
  // sufficient for now
  if (![self checkCodewordSkew:codewordBitCount minCodewordWidth:minCodewordWidth maxCodewordWidth:maxCodewordWidth]) {
    // We could try to use the startX and endX position of the codeword in the same column in the previous row,
    // create the bit count from it and normalize it to 8. This would help with single pixel errors.
    return nil;
  }

  int decodedValue = [ZXPDF417CodewordDecoder decodedValue:moduleBitCount];
  int codeword = [ZXPDF417Common codeword:decodedValue];
  if (codeword == -1) {
    return nil;
  }
  return [[ZXPDF417Codeword alloc] initWithStartX:startColumn endX:endColumn bucket:[self codewordBucketNumber:decodedValue] value:codeword];
}

+ (NSMutableArray *)moduleBitCount:(ZXBitMatrix *)image minColumn:(int)minColumn maxColumn:(int)maxColumn leftToRight:(BOOL)leftToRight
                       startColumn:(int)startColumn imageRow:(int)imageRow {
  int imageColumn = startColumn;
  NSMutableArray *moduleBitCount = [NSMutableArray arrayWithCapacity:8];
  for (int i = 0; i < 8; i++) {
    [moduleBitCount addObject:@0];
  }
  int moduleNumber = 0;
  int increment = leftToRight ? 1 : -1;
  BOOL previousPixelValue = leftToRight;
  while (((leftToRight && imageColumn < maxColumn) || (!leftToRight && imageColumn >= minColumn)) &&
      moduleNumber < [moduleBitCount count]) {
    if ([image getX:imageColumn y:imageRow] == previousPixelValue) {
      moduleBitCount[moduleNumber] = @([moduleBitCount[moduleNumber] intValue] + 1);
      imageColumn += increment;
    } else {
      moduleNumber++;
      previousPixelValue = !previousPixelValue;
    }
  }
  if (moduleNumber == [moduleBitCount count] ||
      (((leftToRight && imageColumn == maxColumn) || (!leftToRight && imageColumn == minColumn)) && moduleNumber == [moduleBitCount count] - 1)) {
    return moduleBitCount;
  }
  return nil;
}

+ (int)numberOfECCodeWords:(int)barcodeECLevel {
  return 2 << barcodeECLevel;
}

+ (int)adjustCodewordStartColumn:(ZXBitMatrix *)image
                       minColumn:(int)minColumn
                       maxColumn:(int)maxColumn
                     leftToRight:(BOOL)leftToRight
             codewordStartColumn:(int)codewordStartColumn
                        imageRow:(int)imageRow {
  int correctedStartColumn = codewordStartColumn;
  int increment = leftToRight ? -1 : 1;
  // there should be no black pixels before the start column. If there are, then we need to start earlier.
  for (int i = 0; i < 2; i++) {
    while (((leftToRight && correctedStartColumn >= minColumn) || (!leftToRight && correctedStartColumn < maxColumn)) &&
           leftToRight == [image getX:correctedStartColumn y:imageRow]) {
      if (abs(codewordStartColumn - correctedStartColumn) > ZXPDF417_CODEWORD_SKEW_SIZE) {
        return codewordStartColumn;
      }
      correctedStartColumn += increment;
    }
    increment = -increment;
    leftToRight = !leftToRight;
  }
  return correctedStartColumn;
}

+ (BOOL)checkCodewordSkew:(int)codewordSize minCodewordWidth:(int)minCodewordWidth maxCodewordWidth:(int)maxCodewordWidth {
  return minCodewordWidth - ZXPDF417_CODEWORD_SKEW_SIZE <= codewordSize &&
      codewordSize <= maxCodewordWidth + ZXPDF417_CODEWORD_SKEW_SIZE;
}

+ (ZXDecoderResult *)decodeCodewords:(NSMutableArray *)codewords ecLevel:(int)ecLevel erasures:(NSArray *)erasures {
  if ([codewords count] == 0) {
    return nil;
  }

  int numECCodewords = 1 << (ecLevel + 1);

  int correctedErrorsCount = [self correctErrors:codewords erasures:erasures numECCodewords:numECCodewords];
  if (correctedErrorsCount == -1) {
    return nil;
  }
  if (![self verifyCodewordCount:codewords numECCodewords:numECCodewords]) {
    return nil;
  }

  // Decode the codewords
  ZXDecoderResult *decoderResult = [ZXPDF417DecodedBitStreamParser decode:codewords ecLevel:[@(ecLevel) stringValue] error:nil];
  decoderResult.errorsCorrected = @(correctedErrorsCount);
  decoderResult.erasures = @([erasures count]);
  return decoderResult;
}

/**
 * Given data and error-correction codewords received, possibly corrupted by errors, attempts to
 * correct the errors in-place.
 */
+ (int)correctErrors:(NSMutableArray *)codewords erasures:(NSArray *)erasures numECCodewords:(int)numECCodewords {
  if ([erasures count] > numECCodewords / 2 + ZXPDF417_MAX_ERRORS || numECCodewords < 0 || numECCodewords > ZXPDF417_MAX_EC_CODEWORDS) {
    // Too many errors or EC Codewords is corrupted
    return -1;
  }
  return [errorCorrection decode:codewords numECCodewords:numECCodewords erasures:erasures];
}

/**
 * Verify that all is OK with the codeword array.
 */
+ (BOOL)verifyCodewordCount:(NSMutableArray *)codewords numECCodewords:(int)numECCodewords {
  if ([codewords count] < 4) {
    // Codeword array size should be at least 4 allowing for
    // Count CW, At least one Data CW, Error Correction CW, Error Correction CW
    return NO;
  }
  // The first codeword, the Symbol Length Descriptor, shall always encode the total number of data
  // codewords in the symbol, including the Symbol Length Descriptor itself, data codewords and pad
  // codewords, but excluding the number of error correction codewords.
  int numberOfCodewords = [codewords[0] intValue];
  if (numberOfCodewords > [codewords count]) {
    return NO;
  }
  if (numberOfCodewords == 0) {
    // Reset to the length of the array - 8 (Allow for at least level 3 Error Correction (8 Error Codewords)
    if (numECCodewords < [codewords count]) {
      codewords[0] = @([codewords count] - numECCodewords);
    } else {
      return NO;
    }
  }

  return YES;
}

+ (NSArray *)bitCountForCodeword:(int)codeword {
  NSMutableArray *result = [NSMutableArray array];
  for (int i = 0; i < 8; i++) {
    [result addObject:@0];
  }

  int previousValue = 0;
  int i = (int)[result count] - 1;
  while (YES) {
    if ((codeword & 0x1) != previousValue) {
      previousValue = codeword & 0x1;
      i--;
      if (i < 0) {
        break;
      }
    }
    result[i] = @([result[i] intValue] + 1);
    codeword >>= 1;
  }
  return result;
}

+ (int)codewordBucketNumber:(int)codeword {
  return [self codewordBucketNumberWithModuleBitCount:[self bitCountForCodeword:codeword]];
}

+ (int)codewordBucketNumberWithModuleBitCount:(NSArray *)moduleBitCount {
  return ([moduleBitCount[0] intValue] - [moduleBitCount[2] intValue] + [moduleBitCount[4] intValue] - [moduleBitCount[6] intValue] + 9) % 9;
}

@end
