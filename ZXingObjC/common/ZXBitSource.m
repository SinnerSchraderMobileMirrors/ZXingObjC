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

#import "ZXBitSource.h"

@interface ZXBitSource ()

@property (nonatomic, assign) int8_t *bytes;
@property (nonatomic, assign) NSInteger byteOffset;
@property (nonatomic, assign) NSInteger bitOffset;
@property (nonatomic, assign) NSInteger length;

@end

@implementation ZXBitSource

/**
 * bytes is the bytes from which this will read bits. Bits will be read from the first byte first.
 * Bits are read within a byte from most-significant to least-significant bit.
 */
- (id)initWithBytes:(int8_t *)bytes length:(NSUInteger)length {
  if (self = [super init]) {
    _bytes = bytes;
    _length = length;
  }
  return self;
}


- (NSInteger)readBits:(NSInteger)numBits {
  if (numBits < 1 || numBits > 32 || numBits > self.available) {
    [NSException raise:NSInvalidArgumentException 
                format:@"Invalid number of bits: %ld", (long)numBits];
  }
  NSInteger result = 0;
  if (self.bitOffset > 0) {
    NSInteger bitsLeft = 8 - self.bitOffset;
    NSInteger toRead = numBits < bitsLeft ? numBits : bitsLeft;
    NSInteger bitsToNotRead = bitsLeft - toRead;
    NSInteger mask = (0xFF >> (8 - toRead)) << bitsToNotRead;
    result = (self.bytes[self.byteOffset] & mask) >> bitsToNotRead;
    numBits -= toRead;
    self.bitOffset += toRead;
    if (self.bitOffset == 8) {
      self.bitOffset = 0;
      self.byteOffset++;
    }
  }

  if (numBits > 0) {
    while (numBits >= 8) {
      result = (result << 8) | (self.bytes[self.byteOffset] & 0xFF);
      self.byteOffset++;
      numBits -= 8;
    }

    if (numBits > 0) {
      NSInteger bitsToNotRead = 8 - numBits;
      NSInteger mask = (0xFF >> bitsToNotRead) << bitsToNotRead;
      result = (result << numBits) | ((self.bytes[self.byteOffset] & mask) >> bitsToNotRead);
      self.bitOffset += numBits;
    }
  }
  return result;
}

- (NSInteger)available {
  return 8 * (self.length - self.byteOffset) - self.bitOffset;
}

@end
