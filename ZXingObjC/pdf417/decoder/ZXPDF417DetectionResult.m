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

#import "ZXPDF417BarcodeMetadata.h"
#import "ZXPDF417BoundingBox.h"
#import "ZXPDF417Codeword.h"
#import "ZXPDF417DetectionResult.h"
#import "ZXPDF417DetectionResultColumn.h"
#import "ZXPDF417DetectionResultRowIndicatorColumn.h"

NSInteger const ADJUST_ROW_NUMBER_SKIP = 2;

@interface ZXPDF417DetectionResult ()

@property (nonatomic, strong) ZXPDF417BarcodeMetadata *barcodeMetadata;
@property (nonatomic, strong) NSMutableArray *detectionResultColumnsInternal;
@property (nonatomic, strong) ZXPDF417BoundingBox *boundingBox;
@property (nonatomic, assign) NSInteger barcodeColumnCount;

@end

@implementation ZXPDF417DetectionResult

- (id)initWithBarcodeMetadata:(ZXPDF417BarcodeMetadata *)barcodeMetadata boundingBox:(ZXPDF417BoundingBox *)boundingBox {
  self = [super init];
  if (self) {
    _barcodeMetadata = barcodeMetadata;
    _barcodeColumnCount = barcodeMetadata.columnCount;
    _boundingBox = boundingBox;
    _detectionResultColumnsInternal = [NSMutableArray arrayWithCapacity:_barcodeColumnCount + 2];
    for (NSInteger i = 0; i < _barcodeColumnCount + 2; i++) {
      [_detectionResultColumnsInternal addObject:[NSNull null]];
    }
  }

  return self;
}

- (NSInteger)imageStartRow:(NSInteger)barcodeColumn {
  while (barcodeColumn > 0) {
    ZXPDF417DetectionResultColumn *detectionResultColumn = self.detectionResultColumnsInternal[--barcodeColumn];
    // TODO compare start row with previous result columns
    // Could try detecting codewords from right to left
    // if all else fails, could calculate estimate
    NSArray *codewords = detectionResultColumn.codewords;
    for (NSInteger rowNumber = 0; rowNumber < [codewords count]; rowNumber++) {
      if (codewords[rowNumber]) {
        // next column might start earlier if barcode is not aligned with image
        if (rowNumber > 0) {
          rowNumber--;
        }
        return [detectionResultColumn imageRow:rowNumber];
      }
    }
  }
  return -1;
}

- (void)setDetectionResultColumn:(NSInteger)barcodeColumn detectionResultColumn:(ZXPDF417DetectionResultColumn *)detectionResultColumn {
  if (!detectionResultColumn) {
    self.detectionResultColumnsInternal[barcodeColumn] = [NSNull null];
  } else {
    self.detectionResultColumnsInternal[barcodeColumn] = detectionResultColumn;
  }
}

- (ZXPDF417DetectionResultColumn *)detectionResultColumn:(NSInteger)barcodeColumn {
  ZXPDF417DetectionResultColumn *result = self.detectionResultColumnsInternal[barcodeColumn];
  return (id)result == [NSNull null] ? nil : result;
}

- (void)adjustIndicatorColumnRowNumbers:(ZXPDF417DetectionResultColumn *)detectionResultColumn {
  if (detectionResultColumn && (id)detectionResultColumn != [NSNull null]) {
    [(ZXPDF417DetectionResultRowIndicatorColumn *) detectionResultColumn adjustIndicatorColumnRowNumbers:self.barcodeMetadata];
  }
}

- (NSArray *)detectionResultColumns {
  [self adjustIndicatorColumnRowNumbers:self.detectionResultColumnsInternal[0]];
  [self adjustIndicatorColumnRowNumbers:self.detectionResultColumnsInternal[self.barcodeColumnCount + 1]];
  NSInteger unadjustedCodewordCount = 900;
  NSInteger previousUnadjustedCount;
  do {
    previousUnadjustedCount = unadjustedCodewordCount;
    unadjustedCodewordCount = [self adjustRowNumbers];
  } while (unadjustedCodewordCount > 0 && unadjustedCodewordCount < previousUnadjustedCount);
  return self.detectionResultColumnsInternal;
}

// TODO ensure that no detected codewords with unknown row number are left
// we should be able to estimate the row height and use it as a hint for the row number
// we should also fill the rows top to bottom and bottom to top
/**
 * Returns the number of codewords which don't have a valid row number. Note that the count is not accurate as codewords
 * will be counted several times. It just serves as an indicator to see when we can stop adjusting row numbers
 */
- (NSInteger)adjustRowNumbers {
  NSInteger unadjustedCount = [self adjustRowNumbersByRow];
  if (unadjustedCount == 0) {
    return 0;
  }
  for (NSInteger barcodeColumn = 1; barcodeColumn < self.barcodeColumnCount + 1; barcodeColumn++) {
    NSArray *codewords = [self.detectionResultColumnsInternal[barcodeColumn] codewords];
    for (NSInteger codewordsRow = 0; codewordsRow < [codewords count]; codewordsRow++) {
      if ((id)codewords[codewordsRow] == [NSNull null]) {
        continue;
      }
      if (![codewords[codewordsRow] hasValidRowNumber]) {
        [self adjustRowNumbers:barcodeColumn codewordsRow:codewordsRow codewords:codewords];
      }
    }
  }
  return unadjustedCount;
}

- (NSInteger)adjustRowNumbersByRow {
  // TODO we should only do full row adjustments if row numbers of left and right row indicator column match.
  // Maybe it's even better to calculated the height (in codeword rows) and divide it by the number of barcode
  // rows. This, together with the LRI and RRI row numbers should allow us to get a good estimate where a row
  // number starts and ends.
  NSInteger unadjustedCount = [self adjustRowNumbersFromLRI];
  return unadjustedCount + [self adjustRowNumbersFromRRI];
}

- (NSInteger)adjustRowNumbersFromRRI {
  if (self.detectionResultColumnsInternal[self.barcodeColumnCount + 1] == [NSNull null]) {
    return 0;
  }
  NSInteger unadjustedCount = 0;
  NSArray *codewords = [self.detectionResultColumnsInternal[self.barcodeColumnCount + 1] codewords];
  for (NSInteger codewordsRow = 0; codewordsRow < [codewords count]; codewordsRow++) {
    if ((id)codewords[codewordsRow] == [NSNull null]) {
      continue;
    }
    NSInteger rowIndicatorRowNumber = [codewords[codewordsRow] rowNumber];
    NSInteger invalidRowCounts = 0;
    for (NSInteger barcodeColumn = self.barcodeColumnCount + 1;
         barcodeColumn > 0 && invalidRowCounts < ADJUST_ROW_NUMBER_SKIP;
         barcodeColumn--) {
      if (self.detectionResultColumnsInternal[barcodeColumn] != [NSNull null]) {
        ZXPDF417Codeword *codeword = [self.detectionResultColumnsInternal[barcodeColumn] codewords][codewordsRow];
        if ((id)codeword != [NSNull null]) {
          invalidRowCounts = [self adjustRowNumberIfValid:rowIndicatorRowNumber invalidRowCounts:invalidRowCounts codeword:codeword];
          if (![codeword hasValidRowNumber]) {
            unadjustedCount++;
          }
        }
      }
    }
  }
  return unadjustedCount;
}

- (NSInteger)adjustRowNumbersFromLRI {
  if (self.detectionResultColumnsInternal[0] == [NSNull null]) {
    return 0;
  }
  NSInteger unadjustedCount = 0;
  NSArray *codewords = [self.detectionResultColumnsInternal[0] codewords];
  for (NSInteger codewordsRow = 0; codewordsRow < [codewords count]; codewordsRow++) {
    if ((id)codewords[codewordsRow] == [NSNull null]) {
      continue;
    }
    NSInteger rowIndicatorRowNumber = [codewords[codewordsRow] rowNumber];
    NSInteger invalidRowCounts = 0;
    for (NSInteger barcodeColumn = 1;
         barcodeColumn < self.barcodeColumnCount + 1 && invalidRowCounts < ADJUST_ROW_NUMBER_SKIP;
         barcodeColumn++) {
      if (self.detectionResultColumnsInternal[barcodeColumn] != [NSNull null]) {
        ZXPDF417Codeword *codeword = [self.detectionResultColumnsInternal[barcodeColumn] codewords][codewordsRow];
        if ((id)codeword != [NSNull null]) {
          invalidRowCounts = [self adjustRowNumberIfValid:rowIndicatorRowNumber invalidRowCounts:invalidRowCounts codeword:codeword];
          if (![codeword hasValidRowNumber]) {
            unadjustedCount++;
          }
        }
      }
    }
  }
  return unadjustedCount;
}

- (NSInteger)adjustRowNumberIfValid:(NSInteger)rowIndicatorRowNumber invalidRowCounts:(NSInteger)invalidRowCounts codeword:(ZXPDF417Codeword *)codeword {
  if (!codeword) {
    return invalidRowCounts;
  }
  if (![codeword hasValidRowNumber]) {
    if ([codeword isValidRowNumber:rowIndicatorRowNumber]) {
      [codeword setRowNumber:rowIndicatorRowNumber];
      invalidRowCounts = 0;
    } else {
      ++invalidRowCounts;
    }
  }
  return invalidRowCounts;
}

- (void)adjustRowNumbers:(NSInteger)barcodeColumn codewordsRow:(NSInteger)codewordsRow codewords:(NSArray *)codewords {
  ZXPDF417Codeword *codeword = codewords[codewordsRow];
  NSArray *previousColumnCodewords = [self.detectionResultColumnsInternal[barcodeColumn - 1] codewords];
  NSArray *nextColumnCodewords = previousColumnCodewords;
  if (self.detectionResultColumnsInternal[barcodeColumn + 1] != [NSNull null]) {
    nextColumnCodewords = [self.detectionResultColumnsInternal[barcodeColumn + 1] codewords];
  }

  NSMutableArray *otherCodewords = [NSMutableArray arrayWithCapacity:14];
  for (NSInteger i = 0; i < 14; i++) {
    [otherCodewords addObject:[NSNull null]];
  }

  otherCodewords[2] = previousColumnCodewords[codewordsRow];
  otherCodewords[3] = nextColumnCodewords[codewordsRow];

  if (codewordsRow > 0) {
    otherCodewords[0] = codewords[codewordsRow - 1];
    otherCodewords[4] = previousColumnCodewords[codewordsRow - 1];
    otherCodewords[5] = nextColumnCodewords[codewordsRow - 1];
  }
  if (codewordsRow > 1) {
    otherCodewords[8] = codewords[codewordsRow - 2];
    otherCodewords[10] = previousColumnCodewords[codewordsRow - 2];
    otherCodewords[11] = nextColumnCodewords[codewordsRow - 2];
  }
  if (codewordsRow < [codewords count] - 1) {
    otherCodewords[1] = codewords[codewordsRow + 1];
    otherCodewords[6] = previousColumnCodewords[codewordsRow + 1];
    otherCodewords[7] = nextColumnCodewords[codewordsRow + 1];
  }
  if (codewordsRow < [codewords count] - 2) {
    otherCodewords[9] = codewords[codewordsRow + 2];
    otherCodewords[12] = previousColumnCodewords[codewordsRow + 2];
    otherCodewords[13] = nextColumnCodewords[codewordsRow + 2];
  }
  for (ZXPDF417Codeword *otherCodeword in otherCodewords) {
    if ([self adjustRowNumber:codeword otherCodeword:otherCodeword]) {
      return;
    }
  }
}

/**
 * Return true if row number was adjusted, false otherwise
 */
- (BOOL)adjustRowNumber:(ZXPDF417Codeword *)codeword otherCodeword:(ZXPDF417Codeword *)otherCodeword {
  if ((id)otherCodeword == [NSNull null]) {
    return NO;
  }
  if ([otherCodeword hasValidRowNumber] && otherCodeword.bucket == codeword.bucket) {
    [codeword setRowNumber:otherCodeword.rowNumber];
    return YES;
  }
  return NO;
}

- (NSInteger)barcodeColumnCount {
  return _barcodeColumnCount;
}

- (NSInteger)barcodeRowCount {
  return self.barcodeMetadata.rowCount;
}

- (NSInteger)barcodeECLevel {
  return self.barcodeMetadata.errorCorrectionLevel;
}

- (ZXPDF417BoundingBox *)boundingBox {
  return _boundingBox;
}

@end
