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

#import "ZXRGBLuminanceSource.h"

@interface ZXRGBLuminanceSource ()

@property (nonatomic, assign) int8_t *luminances;
@property (nonatomic, assign) NSInteger luminancesCount;
@property (nonatomic, assign) NSInteger dataWidth;
@property (nonatomic, assign) NSInteger dataHeight;
@property (nonatomic, assign) NSInteger left;
@property (nonatomic, assign) NSInteger top;

@end

@implementation ZXRGBLuminanceSource

- (id)initWithWidth:(NSInteger)width height:(NSInteger)height pixels:(NSInteger *)pixels pixelsLen:(NSInteger)pixelsLen {
  if (self = [super initWithWidth:width height:height]) {
    _dataWidth = width;
    _dataHeight = height;
    _left = 0;
    _top = 0;

    // In order to measure pure decoding speed, we convert the entire image to a greyscale array
    // up front, which is the same as the Y channel of the YUVLuminanceSource in the real app.
    _luminancesCount = width * height;
    _luminances = (int8_t *)malloc(_luminancesCount * sizeof(int8_t));
    for (NSInteger y = 0; y < height; y++) {
      NSInteger offset = y * width;
      for (NSInteger x = 0; x < width; x++) {
        NSInteger pixel = pixels[offset + x];
        NSInteger r = (pixel >> 16) & 0xff;
        NSInteger g = (pixel >> 8) & 0xff;
        NSInteger b = pixel & 0xff;
        if (r == g && g == b) {
          // Image is already greyscale, so pick any channel.
          _luminances[offset + x] = (char) r;
        } else {
          // Calculate luminance cheaply, favoring green.
          _luminances[offset + x] = (char) ((r + g + g + b) >> 2);
        }
      }
    }
  }

  return self;
}

- (id)initWithPixels:(int8_t *)pixels pixelsLen:(NSInteger)pixelsLen dataWidth:(NSInteger)dataWidth dataHeight:(NSInteger)dataHeight
                left:(NSInteger)left top:(NSInteger)top width:(NSInteger)width height:(NSInteger)height {
  if (self = [super initWithWidth:width height:height]) {
    if (left + self.width > dataWidth || top + self.height > dataHeight) {
      [NSException raise:NSInvalidArgumentException format:@"Crop rectangle does not fit within image data."];
    }

    _luminancesCount = pixelsLen;
    _luminances = (int8_t *)malloc(pixelsLen * sizeof(int8_t));
    memcpy(_luminances, pixels, pixelsLen * sizeof(int8_t));

    _dataWidth = dataWidth;
    _dataHeight = dataHeight;
    _left = left;
    _top = top;
  }

  return self;
}

- (int8_t *)row:(NSInteger)y {
  if (y < 0 || y >= self.height) {
    [NSException raise:NSInvalidArgumentException format:@"Requested row is outside the image: %ld", (long)y];
  }
  int8_t *row = (int8_t *)malloc(self.width * sizeof(int8_t));

  NSInteger offset = (y + self.top) * self.dataWidth + self.left;
  memcpy(row, self.luminances + offset, self.width);
  return row;
}

- (int8_t *)matrix {
  NSInteger area = self.width * self.height;
  int8_t *matrix = (int8_t *)malloc(area * sizeof(int8_t));
  NSInteger inputOffset = self.top * self.dataWidth + self.left;

  // If the width matches the full width of the underlying data, perform a single copy.
  if (self.width == self.dataWidth) {
    memcpy(matrix, self.luminances + inputOffset, area - inputOffset);
    return matrix;
  }

  // Otherwise copy one cropped row at a time.
  for (NSInteger y = 0; y < self.height; y++) {
    NSInteger outputOffset = y * self.width;
    memcpy(matrix + outputOffset, self.luminances + inputOffset, self.width);
    inputOffset += self.dataWidth;
  }
  return matrix;
}

- (BOOL)cropSupported {
  return YES;
}

- (ZXLuminanceSource *)crop:(NSInteger)left top:(NSInteger)top width:(NSInteger)width height:(NSInteger)height {
  return [[[self class] alloc] initWithPixels:self.luminances
                                    pixelsLen:self.luminancesCount
                                    dataWidth:self.dataWidth
                                   dataHeight:self.dataHeight
                                         left:self.left + left
                                          top:self.top + top
                                        width:width
                                       height:height];
}

@end
