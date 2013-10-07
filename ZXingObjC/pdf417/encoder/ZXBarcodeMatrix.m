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

#import "ZXBarcodeMatrix.h"
#import "ZXBarcodeRow.h"

@interface ZXBarcodeMatrix ()

@property (nonatomic, assign) NSInteger currentRowIndex;
@property (nonatomic, strong) NSArray *rowMatrix;

@end

@implementation ZXBarcodeMatrix

- (id)initWithHeight:(NSInteger)height width:(NSInteger)width {
  if (self = [super init]) {
    NSMutableArray *matrix = [NSMutableArray array];
    for (NSInteger i = 0, matrixLength = height + 2; i < matrixLength; i++) {
      [matrix addObject:[ZXBarcodeRow barcodeRowWithWidth:(width + 4) * 17 + 1]];
    }
    _rowMatrix = matrix;
    _width = width * 17;
    _height = height + 2;
    _currentRowIndex = 0;
  }

  return self;
}

- (void)setX:(NSInteger)x y:(NSInteger)y value:(int8_t)value {
  [self.rowMatrix[y] setX:x value:value];
}

- (void)setMatrixX:(NSInteger)x y:(NSInteger)y black:(BOOL)black {
  [self setX:x y:y value:(int8_t)(black ? 1 : 0)];
}

- (void)startRow {
  ++self.currentRowIndex;
}

- (ZXBarcodeRow *)currentRow {
  return self.rowMatrix[self.currentRowIndex];
}

- (int8_t **)matrixWithHeight:(NSInteger *)pHeight width:(NSInteger *)pWidth {
  return [self scaledMatrixWithHeight:pHeight width:pWidth xScale:1 yScale:1];
}

- (int8_t **)scaledMatrixWithHeight:(NSInteger *)pHeight width:(NSInteger *)pWidth scale:(NSInteger)scale {
  return [self scaledMatrixWithHeight:pHeight width:pWidth xScale:scale yScale:scale];
}

- (int8_t **)scaledMatrixWithHeight:(NSInteger *)pHeight width:(NSInteger *)pWidth xScale:(NSInteger)xScale yScale:(NSInteger)yScale {
  NSInteger matrixHeight = self.height * yScale;

  if (pHeight) *pHeight = matrixHeight;
  if (pWidth) *pWidth = (self.width + 69) * xScale;

  int8_t **matrixOut = (int8_t **)malloc(matrixHeight * sizeof(int8_t *));
  NSInteger yMax = self.height * yScale;
  for (NSInteger ii = 0; ii < yMax; ii++) {
    matrixOut[yMax - ii - 1] = [self.rowMatrix[ii / yScale] scaledRow:xScale];
  }
  return matrixOut;
}

@end
