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

/**
 * A simple, fast array of bits, represented compactly by an array of ints internally.
 */

@interface ZXBitArray : NSObject

@property (nonatomic, readonly) int8_t *bits;
@property (nonatomic, readonly) NSUInteger size;

- (id)initWithSize:(NSUInteger)size;
- (NSUInteger)sizeInBytes;
- (BOOL)get:(NSUInteger)i;
- (void)set:(NSUInteger)i;
- (void)flip:(NSUInteger)i;
- (NSUInteger)nextSet:(NSUInteger)from;
- (NSUInteger)nextUnset:(NSUInteger)from;
- (void)setBulk:(NSUInteger)i newBits:(int8_t)newBits;
- (void)setRange:(NSUInteger)start end:(NSInteger)end;
- (void)clear;
- (BOOL)isRange:(NSUInteger)start end:(NSUInteger)end value:(BOOL)value;
- (void)appendBit:(BOOL)bit;
- (void)appendBits:(int8_t)value numBits:(NSUInteger)numBits;
- (void)appendBitArray:(ZXBitArray *)other;
- (void)xor:(ZXBitArray *)other;
- (void)toBytes:(NSUInteger)bitOffset array:(int8_t *)array offset:(NSUInteger)offset numBytes:(NSUInteger)numBytes;
- (void)reverse;

@end
