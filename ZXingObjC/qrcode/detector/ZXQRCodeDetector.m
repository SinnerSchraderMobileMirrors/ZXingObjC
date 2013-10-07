/*
 * Copyright 2012 ZXing authors
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

#import "ZXAlignmentPattern.h"
#import "ZXAlignmentPatternFinder.h"
#import "ZXBitMatrix.h"
#import "ZXDecodeHints.h"
#import "ZXDetectorResult.h"
#import "ZXErrors.h"
#import "ZXFinderPatternFinder.h"
#import "ZXFinderPatternInfo.h"
#import "ZXGridSampler.h"
#import "ZXMathUtils.h"
#import "ZXPerspectiveTransform.h"
#import "ZXQRCodeDetector.h"
#import "ZXQRCodeFinderPattern.h"
#import "ZXQRCodeVersion.h"
#import "ZXResultPoint.h"
#import "ZXResultPointCallback.h"

@interface ZXQRCodeDetector ()

@property (nonatomic, weak) id <ZXResultPointCallback> resultPointCallback;

@end

@implementation ZXQRCodeDetector

- (id)initWithImage:(ZXBitMatrix *)image {
  if (self = [super init]) {
    _image = image;
  }

  return self;
}

/**
 * Detects a QR Code in an image, simply.
 */
- (ZXDetectorResult *)detectWithError:(NSError **)error {
  return [self detect:nil error:error];
}

/**
 * Detects a QR Code in an image, simply.
 */
- (ZXDetectorResult *)detect:(ZXDecodeHints *)hints error:(NSError **)error {
  self.resultPointCallback = hints == nil ? nil : hints.resultPointCallback;

  ZXFinderPatternFinder *finder = [[ZXFinderPatternFinder alloc] initWithImage:self.image resultPointCallback:self.resultPointCallback];
  ZXFinderPatternInfo *info = [finder find:hints error:error];
  if (!info) {
    return nil;
  }

  return [self processFinderPatternInfo:info error:error];
}

- (ZXDetectorResult *)processFinderPatternInfo:(ZXFinderPatternInfo *)info error:(NSError **)error {
  ZXQRCodeFinderPattern *topLeft = info.topLeft;
  ZXQRCodeFinderPattern *topRight = info.topRight;
  ZXQRCodeFinderPattern *bottomLeft = info.bottomLeft;

  float moduleSize = [self calculateModuleSize:topLeft topRight:topRight bottomLeft:bottomLeft];
  if (moduleSize < 1.0f) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }
  NSInteger dimension = [ZXQRCodeDetector computeDimension:topLeft topRight:topRight bottomLeft:bottomLeft moduleSize:moduleSize error:error];
  if (dimension == -1) {
    return nil;
  }

  ZXQRCodeVersion *provisionalVersion = [ZXQRCodeVersion provisionalVersionForDimension:dimension];
  if (!provisionalVersion) {
    if (error) *error = FormatErrorInstance();
    return nil;
  }
  NSInteger modulesBetweenFPCenters = [provisionalVersion dimensionForVersion] - 7;

  ZXAlignmentPattern *alignmentPattern = nil;
  if ([[provisionalVersion alignmentPatternCenters] count] > 0) {
    float bottomRightX = [topRight x] - [topLeft x] + [bottomLeft x];
    float bottomRightY = [topRight y] - [topLeft y] + [bottomLeft y];

    float correctionToTopLeft = 1.0f - 3.0f / (float)modulesBetweenFPCenters;
    NSInteger estAlignmentX = (NSInteger)([topLeft x] + correctionToTopLeft * (bottomRightX - [topLeft x]));
    NSInteger estAlignmentY = (NSInteger)([topLeft y] + correctionToTopLeft * (bottomRightY - [topLeft y]));

    for (NSInteger i = 4; i <= 16; i <<= 1) {
      NSError *alignmentError = nil;
      alignmentPattern = [self findAlignmentInRegion:moduleSize estAlignmentX:estAlignmentX estAlignmentY:estAlignmentY allowanceFactor:(float)i error:&alignmentError];
      if (alignmentPattern) {
        break;
      } else if (alignmentError.code != ZXNotFoundError) {
        if (error) *error = alignmentError;
        return nil;
      }
    }
  }

  ZXPerspectiveTransform *transform = [ZXQRCodeDetector createTransform:topLeft topRight:topRight bottomLeft:bottomLeft alignmentPattern:alignmentPattern dimension:dimension];
  ZXBitMatrix *bits = [self sampleGrid:self.image transform:transform dimension:dimension error:error];
  if (!bits) {
    return nil;
  }
  NSArray *points;
  if (alignmentPattern == nil) {
    points = @[bottomLeft, topLeft, topRight];
  } else {
    points = @[bottomLeft, topLeft, topRight, alignmentPattern];
  }
  return [[ZXDetectorResult alloc] initWithBits:bits points:points];
}

+ (ZXPerspectiveTransform *)createTransform:(ZXResultPoint *)topLeft topRight:(ZXResultPoint *)topRight bottomLeft:(ZXResultPoint *)bottomLeft alignmentPattern:(ZXResultPoint *)alignmentPattern dimension:(NSInteger)dimension {
  float dimMinusThree = (float)dimension - 3.5f;
  float bottomRightX;
  float bottomRightY;
  float sourceBottomRightX;
  float sourceBottomRightY;
  if (alignmentPattern != nil) {
    bottomRightX = alignmentPattern.x;
    bottomRightY = alignmentPattern.y;
    sourceBottomRightX = dimMinusThree - 3.0f;
    sourceBottomRightY = sourceBottomRightX;
  } else {
    bottomRightX = (topRight.x - topLeft.x) + bottomLeft.x;
    bottomRightY = (topRight.y - topLeft.y) + bottomLeft.y;
    sourceBottomRightX = dimMinusThree;
    sourceBottomRightY = dimMinusThree;
  }
  return [ZXPerspectiveTransform quadrilateralToQuadrilateral:3.5f y0:3.5f
                                                           x1:dimMinusThree y1:3.5f
                                                           x2:sourceBottomRightX y2:sourceBottomRightY
                                                           x3:3.5f y3:dimMinusThree
                                                          x0p:topLeft.x y0p:topLeft.y
                                                          x1p:topRight.x y1p:topRight.y
                                                          x2p:bottomRightX y2p:bottomRightY
                                                          x3p:bottomLeft.x y3p:bottomLeft.y];
}

- (ZXBitMatrix *)sampleGrid:(ZXBitMatrix *)anImage transform:(ZXPerspectiveTransform *)transform dimension:(NSInteger)dimension error:(NSError **)error {
  ZXGridSampler *sampler = [ZXGridSampler instance];
  return [sampler sampleGrid:anImage dimensionX:dimension dimensionY:dimension transform:transform error:error];
}

/**
 * Computes the dimension (number of modules on a size) of the QR Code based on the position
 * of the finder patterns and estimated module size. Returns -1 on an error.
 */
+ (NSInteger)computeDimension:(ZXResultPoint *)topLeft topRight:(ZXResultPoint *)topRight bottomLeft:(ZXResultPoint *)bottomLeft moduleSize:(float)moduleSize error:(NSError **)error {
  NSInteger tltrCentersDimension = [ZXMathUtils round:[ZXResultPoint distance:topLeft pattern2:topRight] / moduleSize];
  NSInteger tlblCentersDimension = [ZXMathUtils round:[ZXResultPoint distance:topLeft pattern2:bottomLeft] / moduleSize];
  NSInteger dimension = ((tltrCentersDimension + tlblCentersDimension) >> 1) + 7;

  switch (dimension & 0x03) {
  case 0:
    dimension++;
    break;
  case 2:
    dimension--;
    break;
  case 3:
    if (error) *error = NotFoundErrorInstance();
    return -1;
  }
  return dimension;
}

/**
 * Computes an average estimated module size based on estimated derived from the positions
 * of the three finder patterns.
 */
- (float)calculateModuleSize:(ZXResultPoint *)topLeft topRight:(ZXResultPoint *)topRight bottomLeft:(ZXResultPoint *)bottomLeft {
  return ([self calculateModuleSizeOneWay:topLeft otherPattern:topRight] + [self calculateModuleSizeOneWay:topLeft otherPattern:bottomLeft]) / 2.0f;
}

- (float)calculateModuleSizeOneWay:(ZXResultPoint *)pattern otherPattern:(ZXResultPoint *)otherPattern {
  float moduleSizeEst1 = [self sizeOfBlackWhiteBlackRunBothWays:(NSInteger)[pattern x] fromY:(NSInteger)[pattern y] toX:(NSInteger)[otherPattern x] toY:(NSInteger)[otherPattern y]];
  float moduleSizeEst2 = [self sizeOfBlackWhiteBlackRunBothWays:(NSInteger)[otherPattern x] fromY:(NSInteger)[otherPattern y] toX:(NSInteger)[pattern x] toY:(NSInteger)[pattern y]];
  if (isnan(moduleSizeEst1)) {
    return moduleSizeEst2 / 7.0f;
  }
  if (isnan(moduleSizeEst2)) {
    return moduleSizeEst1 / 7.0f;
  }
  return (moduleSizeEst1 + moduleSizeEst2) / 14.0f;
}

- (float)sizeOfBlackWhiteBlackRunBothWays:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY {
  float result = [self sizeOfBlackWhiteBlackRun:fromX fromY:fromY toX:toX toY:toY];

  // Now count other way -- don't run off image though of course
  float scale = 1.0f;
  NSInteger otherToX = fromX - (toX - fromX);
  if (otherToX < 0) {
    scale = (float)fromX / (float)(fromX - otherToX);
    otherToX = 0;
  } else if (otherToX >= self.image.width) {
    scale = (float)(self.image.width - 1 - fromX) / (float)(otherToX - fromX);
    otherToX = self.image.width - 1;
  }
  NSInteger otherToY = (NSInteger)(fromY - (toY - fromY) * scale);

  scale = 1.0f;
  if (otherToY < 0) {
    scale = (float)fromY / (float)(fromY - otherToY);
    otherToY = 0;
  } else if (otherToY >= self.image.height) {
    scale = (float)(self.image.height - 1 - fromY) / (float)(otherToY - fromY);
    otherToY = self.image.height - 1;
  }
  otherToX = (NSInteger)(fromX + (otherToX - fromX) * scale);

  result += [self sizeOfBlackWhiteBlackRun:fromX fromY:fromY toX:otherToX toY:otherToY];

  // Middle pixel is double-counted this way; subtract 1
  return result - 1.0f;
}

/**
 * This method traces a line from a point in the image, in the direction towards another point.
 * It begins in a black region, and keeps going until it finds white, then black, then white again.
 * It reports the distance from the start to this point.
 * 
 * This is used when figuring out how wide a finder pattern is, when the finder pattern
 * may be skewed or rotated.
 */
- (float)sizeOfBlackWhiteBlackRun:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY {
  // Mild variant of Bresenham's algorithm;
  // see http://en.wikipedia.org/wiki/Bresenham's_line_algorithm
  BOOL steep = ABS(toY - fromY) > ABS(toX - fromX);
  if (steep) {
    NSInteger temp = fromX;
    fromX = fromY;
    fromY = temp;
    temp = toX;
    toX = toY;
    toY = temp;
  }

  NSInteger dx = ABS(toX - fromX);
  NSInteger dy = ABS(toY - fromY);
  NSInteger error = -dx >> 1;
  NSInteger xstep = fromX < toX ? 1 : -1;
  NSInteger ystep = fromY < toY ? 1 : -1;

  // In black pixels, looking for white, first or second time.
  NSInteger state = 0;
  // Loop up until x == toX, but not beyond
  NSInteger xLimit = toX + xstep;
  for (NSInteger x = fromX, y = fromY; x != xLimit; x += xstep) {
    NSInteger realX = steep ? y : x;
    NSInteger realY = steep ? x : y;

    // Does current pixel mean we have moved white to black or vice versa?
    // Scanning black in state 0,2 and white in state 1, so if we find the wrong
    // color, advance to next state or end if we are in state 2 already
    if ((state == 1) == [self.image getX:realX y:realY]) {
      if (state == 2) {
        return [ZXMathUtils distanceInt:x aY:y bX:fromX bY:fromY];
      }
      state++;
    }

    error += dy;
    if (error > 0) {
      if (y == toY) {
        break;
      }
      y += ystep;
      error -= dx;
    }
  }
  // Found black-white-black; give the benefit of the doubt that the next pixel outside the image
  // is "white" so this last point at (toX+xStep,toY) is the right ending. This is really a
  // small approximation; (toX+xStep,toY+yStep) might be really correct. Ignore this.
  if (state == 2) {
    return [ZXMathUtils distanceInt:toX + xstep aY:toY bX:fromX bY:fromY];
  }
  // else we didn't find even black-white-black; no estimate is really possible
  return NAN;
}

/**
 * Attempts to locate an alignment pattern in a limited region of the image, which is
 * guessed to contain it. This method uses ZXAlignmentPattern.
 */
- (ZXAlignmentPattern *)findAlignmentInRegion:(float)overallEstModuleSize estAlignmentX:(NSInteger)estAlignmentX estAlignmentY:(NSInteger)estAlignmentY allowanceFactor:(float)allowanceFactor error:(NSError **)error {
  NSInteger allowance = (NSInteger)(allowanceFactor * overallEstModuleSize);
  NSInteger alignmentAreaLeftX = MAX(0, estAlignmentX - allowance);
  NSInteger alignmentAreaRightX = MIN(self.image.width - 1, estAlignmentX + allowance);
  if (alignmentAreaRightX - alignmentAreaLeftX < overallEstModuleSize * 3) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }

  NSInteger alignmentAreaTopY = MAX(0, estAlignmentY - allowance);
  NSInteger alignmentAreaBottomY = MIN(self.image.height - 1, estAlignmentY + allowance);
  if (alignmentAreaBottomY - alignmentAreaTopY < overallEstModuleSize * 3) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }

  ZXAlignmentPatternFinder *alignmentFinder = [[ZXAlignmentPatternFinder alloc] initWithImage:self.image
                                                                                       startX:alignmentAreaLeftX
                                                                                       startY:alignmentAreaTopY
                                                                                        width:alignmentAreaRightX - alignmentAreaLeftX
                                                                                       height:alignmentAreaBottomY - alignmentAreaTopY
                                                                                   moduleSize:overallEstModuleSize
                                                                          resultPointCallback:self.resultPointCallback];
  return [alignmentFinder findWithError:error];
}

@end
