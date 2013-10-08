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
 * Represents a 2D matrix of bits. In function arguments below, and throughout the common
 * module, x is the column position, and y is the row position. The ordering is always x, y.
 * The origin is at the top-left.
 * 
 * Internally the bits are represented in a 1-D array of 32-bit ints. However, each row begins
 * with a new NSInteger. This is done intentionally so that we can copy out a row into a BitArray very
 * efficiently.
 * 
 * The ordering of bits is row-major. Within each NSInteger, the least significant bits are used first,
 * meaning they represent lower x values. This is compatible with BitArray's implementation.
 */

@class ZXBitArray;

@interface ZXBitMatrix : NSObject

@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;
@property (nonatomic, readonly) int32_t *bits;

+ (ZXBitMatrix *)bitMatrixWithDimension:(NSUInteger)dimension;
+ (ZXBitMatrix *)bitMatrixWithWidth:(NSUInteger)width height:(NSUInteger)height;

- (id)initWithDimension:(NSUInteger)dimension;
- (id)initWithWidth:(NSUInteger)width height:(NSUInteger)height;

- (BOOL)getX:(NSUInteger)x y:(NSUInteger)y;
- (void)setX:(NSUInteger)x y:(NSUInteger)y;
- (void)flipX:(NSUInteger)x y:(NSUInteger)y;
- (void)clear;
- (void)setRegionAtLeft:(NSUInteger)left top:(NSUInteger)top width:(NSUInteger)width height:(NSUInteger)height;
- (ZXBitArray *)rowAtY:(NSUInteger)y row:(ZXBitArray *)row;
- (void)setRowAtY:(NSUInteger)y row:(ZXBitArray *)row;
- (NSArray *)enclosingRectangle;
- (NSArray *)topLeftOnBit;
- (NSArray *)bottomRightOnBit;

@end
