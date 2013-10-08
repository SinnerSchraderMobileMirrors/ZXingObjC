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

#import "ZXBitArray.h"

@interface ZXBitArray ()

@property (nonatomic, assign) int32_t *bits;
@property (nonatomic, assign) NSUInteger bitsLength;
@property (nonatomic, assign) NSUInteger size;

@end

@implementation ZXBitArray

- (id)init {
  if (self = [super init]) {
    _size = 0;
    _bits = (int32_t *)malloc(1 * sizeof(int32_t));
    _bitsLength = 1;
    _bits[0] = 0;
  }

  return self;
}

- (id)initWithSize:(NSUInteger)size {
  if (self = [super init]) {
    _size = size;
    _bits = [self makeArray:size];
    _bitsLength = (size + 31) >> 5;
  }

  return self;
}


- (void)dealloc {
  if (_bits != NULL) {
    free(_bits);
    _bits = NULL;
  }
}

- (NSUInteger)sizeInBytes {
  return (self.size + 7) >> 3;
}

- (void)ensureCapacity:(NSUInteger)aSize {
  if (aSize > self.bitsLength << 5) {
    int32_t *newBits = [self makeArray:aSize];

    for (NSUInteger i = 0; i < self.bitsLength; i++) {
      newBits[i] = self.bits[i];
    }

    if (self.bits != NULL) {
      free(self.bits);
      self.bits = NULL;
    }
    self.bits = newBits;
    self.bitsLength = (aSize + 31) >> 5;
  }
}


- (BOOL)get:(NSUInteger)i {
  return (self.bits[i >> 5] & (1 << (i & 0x1F))) != 0;
}


- (void)set:(NSUInteger)i {
  self.bits[i >> 5] |= 1 << (i & 0x1F);
}


/**
 * Flips bit i.
 */
- (void)flip:(NSUInteger)i {
  self.bits[i >> 5] ^= 1 << (i & 0x1F);
}

- (NSInteger)nextSet:(NSUInteger)from {
  if (from >= self.size) {
    return self.size;
  }
  NSUInteger bitsOffset = from >> 5;
  int32_t currentBits = self.bits[bitsOffset];
  // mask off lesser bits first
  currentBits &= ~((1 << (from & 0x1F)) - 1);
  while (currentBits == 0) {
    if (++bitsOffset == self.bitsLength) {
      return self.size;
    }
    currentBits = self.bits[bitsOffset];
  }
  NSUInteger result = (bitsOffset << 5) + [self numberOfTrailingZeros:currentBits];
  return result > self.size ? self.size : result;
}

- (NSInteger)nextUnset:(NSUInteger)from {
  if (from >= self.size) {
    return self.size;
  }
  NSUInteger bitsOffset = from >> 5;
  int32_t currentBits = ~self.bits[bitsOffset];
  // mask off lesser bits first
  currentBits &= ~((1 << (from & 0x1F)) - 1);
  while (currentBits == 0) {
    if (++bitsOffset == self.bitsLength) {
      return self.size;
    }
    currentBits = ~self.bits[bitsOffset];
  }
  NSUInteger result = (bitsOffset << 5) + [self numberOfTrailingZeros:currentBits];
  return result > self.size ? self.size : result;
}

/**
 * Sets a block of 32 bits, starting at bit i.
 * 
 * newBits is the new value of the next 32 bits. Note again that the least-significant bit
 * corresponds to bit i, the next-least-significant to i+1, and so on.
 */
- (void)setBulk:(NSUInteger)i newBits:(int32_t)newBits {
  self.bits[i >> 5] = newBits;
}

/**
 * Sets a range of bits.
 */
- (void)setRange:(NSUInteger)start end:(NSInteger)end {
  if (end < start) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Start greater than end" userInfo:nil];
  }
  if (end == start) {
    return;
  }
  end--; // will be easier to treat this as the last actually set bit -- inclusive
  NSUInteger firstInt = start >> 5;
  NSUInteger lastInt = end >> 5;
  for (NSUInteger i = firstInt; i <= lastInt; i++) {
    NSUInteger firstBit = i > firstInt ? 0 : start & 0x1F;
    NSUInteger lastBit = i < lastInt ? 31 : end & 0x1F;
    int32_t mask;
    if (firstBit == 0 && lastBit == 31) {
      mask = -1;
    } else {
      mask = 0;
      for (NSUInteger j = firstBit; j <= lastBit; j++) {
        mask |= 1 << j;
      }
    }
    self.bits[i] |= mask;
  }
}

/**
 * Clears all bits (sets to false).
 */
- (void)clear {
  memset(self.bits, 0, self.bitsLength * sizeof(int32_t));
}

/**
 * Efficient method to check if a range of bits is set, or not set.
 */
- (BOOL)isRange:(NSUInteger)start end:(NSUInteger)end value:(BOOL)value {
  if (end < start) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Start greater than end" userInfo:nil];
  }
  if (end == start) {
    return YES;
  }
  end--;
  NSUInteger firstInt = start >> 5;
  NSUInteger lastInt = end >> 5;

  for (NSUInteger i = firstInt; i <= lastInt; i++) {
    NSUInteger firstBit = i > firstInt ? 0 : start & 0x1F;
    NSUInteger lastBit = i < lastInt ? 31 : end & 0x1F;
    int32_t mask;
    if (firstBit == 0 && lastBit == 31) {
      mask = -1;
    } else {
      mask = 0;

      for (NSInteger j = firstBit; j <= lastBit; j++) {
        mask |= 1 << j;
      }
    }
    if ((self.bits[i] & mask) != (value ? mask : 0)) {
      return NO;
    }
  }

  return YES;
}

- (void)appendBit:(BOOL)bit {
  [self ensureCapacity:self.size + 1];
  if (bit) {
    self.bits[self.size >> 5] |= 1 << (self.size & 0x1F);
  }
  self.size++;
}

/**
 * Appends the least-significant bits, from value, in order from most-significant to
 * least-significant. For example, appending 6 bits from 0x000001E will append the bits
 * 0, 1, 1, 1, 1, 0 in that order.
 */
- (void)appendBits:(int32_t)value numBits:(NSUInteger)numBits {
  if (numBits > 32) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"Num bits must be between 0 and 32"
                                 userInfo:nil];
  }
  [self ensureCapacity:self.size + numBits];
  for (NSInteger numBitsLeft = numBits; numBitsLeft > 0; numBitsLeft--) {
    [self appendBit:((value >> (numBitsLeft - 1)) & 0x01) == 1];
  }
}

- (void)appendBitArray:(ZXBitArray *)other {
  NSUInteger otherSize = [other size];
  [self ensureCapacity:self.size + otherSize];

  for (NSUInteger i = 0; i < otherSize; i++) {
    [self appendBit:[other get:i]];
  }
}

- (void)xor:(ZXBitArray *)other {
  if (self.bitsLength != other.bitsLength) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:@"Sizes don't match"
                                 userInfo:nil];
  }

  for (NSUInteger i = 0; i < self.bitsLength; i++) {
    self.bits[i] ^= other.bits[i];
  }
}


- (void)toBytes:(NSUInteger)bitOffset array:(int8_t *)array offset:(NSUInteger)offset numBytes:(NSUInteger)numBytes {
  for (NSUInteger i = 0; i < numBytes; i++) {
    int32_t theByte = 0;
    for (NSUInteger j = 0; j < 8; j++) {
      if ([self get:bitOffset]) {
        theByte |= 1 << (7 - j);
      }
      bitOffset++;
    }
    array[offset + i] = (int8_t)theByte;
  }
}

/**
 * Reverses all bits in the array.
 */
- (void)reverse {
  int32_t *newBits = (int32_t *)malloc(self.size * sizeof(int32_t));
  memset(newBits, 0, self.size * sizeof(int32_t));
  for (NSUInteger i = 0; i < self.size; i++) {
    if ([self get:self.size - i - 1]) {
      newBits[i >> 5] |= 1 << (i & 0x1F);
    }
  }

  if (self.bits != NULL) {
    free(self.bits);
  }
  self.bits = newBits;
}

- (int32_t *)makeArray:(NSUInteger)aSize {
  NSUInteger arraySize = (aSize + 31) >> 5;
  int32_t *newArray = (int32_t *)malloc(arraySize * sizeof(int32_t));
  memset(newArray, 0, arraySize * sizeof(int32_t));
  return newArray;
}

- (NSString *)description {
  NSMutableString *result = [NSMutableString string];

  for (NSUInteger i = 0; i < self.size; i++) {
    if ((i & 0x07) == 0) {
      [result appendString:@" "];
    }
    [result appendString:[self get:i] ? @"X" : @"."];
  }

  return result;
}

// Ported from OpenJDK Integer.numberOfTrailingZeros implementation
- (int32_t)numberOfTrailingZeros:(int32_t)i {
  int32_t y;
  if (i == 0) return 32;
  int32_t n = 31;
  y = i <<16; if (y != 0) { n = n -16; i = y; }
  y = i << 8; if (y != 0) { n = n - 8; i = y; }
  y = i << 4; if (y != 0) { n = n - 4; i = y; }
  y = i << 2; if (y != 0) { n = n - 2; i = y; }
  return n - (int32_t)((uint32_t)(i << 1) >> 31);
}

@end
