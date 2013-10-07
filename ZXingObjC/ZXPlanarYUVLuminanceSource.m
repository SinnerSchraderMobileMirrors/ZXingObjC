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

#import "ZXPlanarYUVLuminanceSource.h"

const NSInteger THUMBNAIL_SCALE_FACTOR = 2;

@interface ZXPlanarYUVLuminanceSource ()

@property (nonatomic, assign) int8_t *yuvData;
@property (nonatomic, assign) NSInteger yuvDataLen;
@property (nonatomic, assign) NSInteger dataWidth;
@property (nonatomic, assign) NSInteger dataHeight;
@property (nonatomic, assign) NSInteger left;
@property (nonatomic, assign) NSInteger top;

@end

@implementation ZXPlanarYUVLuminanceSource

- (id)initWithYuvData:(int8_t *)yuvData yuvDataLen:(NSInteger)yuvDataLen dataWidth:(NSInteger)dataWidth
           dataHeight:(NSInteger)dataHeight left:(NSInteger)left top:(NSInteger)top width:(NSInteger)width height:(NSInteger)height
    reverseHorizontal:(BOOL)reverseHorizontal {
  if (self = [super initWithWidth:width height:height]) {
    if (left + width > dataWidth || top + height > dataHeight) {
      [NSException raise:NSInvalidArgumentException format:@"Crop rectangle does not fit within image data."];
    }

    _yuvDataLen = yuvDataLen;
    _yuvData = (int8_t *)malloc(yuvDataLen * sizeof(int8_t));
    memcpy(_yuvData, yuvData, yuvDataLen);
    _dataWidth = dataWidth;
    _dataHeight = dataHeight;
    _left = left;
    _top = top;
    if (reverseHorizontal) {
      [self reverseHorizontal:width height:height];
    }
  }

  return self;
}

- (void)dealloc {
  if (_yuvData != NULL) {
    free(_yuvData);
    _yuvData = NULL;
  }
}

- (int8_t *)row:(NSInteger)y {
  if (y < 0 || y >= self.height) {
    [NSException raise:NSInvalidArgumentException
                format:@"Requested row is outside the image: %ld", (long)y];
  }
  int8_t *row = (int8_t *)malloc(self.width * sizeof(int8_t));
  NSInteger offset = (y + self.top) * self.dataWidth + self.left;
  memcpy(row, self.yuvData + offset, self.width);
  return row;
}

- (int8_t *)matrix {
  NSInteger area = self.width * self.height;
  int8_t *matrix = malloc(area * sizeof(int8_t));
  NSInteger inputOffset = self.top * self.dataWidth + self.left;

  // If the width matches the full width of the underlying data, perform a single copy.
  if (self.width == self.dataWidth) {
    memcpy(matrix, self.yuvData + inputOffset, area - inputOffset);
    return matrix;
  }

  // Otherwise copy one cropped row at a time.
  for (NSInteger y = 0; y < self.height; y++) {
    NSInteger outputOffset = y * self.width;
    memcpy(matrix + outputOffset, self.yuvData + inputOffset, self.width);
    inputOffset += self.dataWidth;
  }
  return matrix;
}

- (BOOL)cropSupported {
  return YES;
}

- (ZXLuminanceSource *)crop:(NSInteger)left top:(NSInteger)top width:(NSInteger)width height:(NSInteger)height {
  return [[[self class] alloc] initWithYuvData:self.yuvData yuvDataLen:self.yuvDataLen dataWidth:self.dataWidth
                                    dataHeight:self.dataHeight left:self.left + left top:self.top + top
                                         width:width height:height reverseHorizontal:NO];
}

- (NSInteger *)renderThumbnail {
  NSInteger thumbWidth = self.width / THUMBNAIL_SCALE_FACTOR;
  NSInteger thumbHeight = self.height / THUMBNAIL_SCALE_FACTOR;
  NSInteger *pixels = (NSInteger *)malloc(thumbWidth * thumbHeight * sizeof(NSInteger));
  NSInteger inputOffset = self.top * self.dataWidth + self.left;

  for (NSInteger y = 0; y < self.height; y++) {
    NSInteger outputOffset = y * self.width;
    for (NSInteger x = 0; x < self.width; x++) {
      NSInteger grey = self.yuvData[inputOffset + x * THUMBNAIL_SCALE_FACTOR] & 0xff;
      pixels[outputOffset + x] = 0xFF000000 | (grey * 0x00010101);
    }
    inputOffset += self.dataWidth * THUMBNAIL_SCALE_FACTOR;
  }
  return pixels;
}

- (NSInteger)thumbnailWidth {
  return self.width / THUMBNAIL_SCALE_FACTOR;
}

- (NSInteger)thumbnailHeight {
  return self.height / THUMBNAIL_SCALE_FACTOR;
}

- (void)reverseHorizontal:(NSInteger)_width height:(NSInteger)_height {
  for (NSInteger y = 0, rowStart = self.top * self.dataWidth + self.left; y < _height; y++, rowStart += self.dataWidth) {
    NSInteger middle = rowStart + _width / 2;
    for (NSInteger x1 = rowStart, x2 = rowStart + _width - 1; x1 < middle; x1++, x2--) {
      int8_t temp = self.yuvData[x1];
      self.yuvData[x1] = self.yuvData[x2];
      self.yuvData[x2] = temp;
    }
  }
}

@end
