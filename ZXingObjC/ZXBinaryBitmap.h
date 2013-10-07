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
 * This class is the core bitmap class used by ZXing to represent 1 bit data. Reader objects
 * accept a BinaryBitmap and attempt to decode it.
 */

@class ZXBinarizer, ZXBitArray, ZXBitMatrix;

@interface ZXBinaryBitmap : NSObject

@property (nonatomic, readonly) NSInteger width;
@property (nonatomic, readonly) NSInteger height;
@property (nonatomic, readonly) BOOL cropSupported;
@property (nonatomic, readonly) BOOL rotateSupported;

- (id)initWithBinarizer:(ZXBinarizer *)binarizer;
+ (id)binaryBitmapWithBinarizer:(ZXBinarizer *)binarizer;
- (ZXBitArray *)blackRow:(NSInteger)y row:(ZXBitArray *)row error:(NSError **)error;
- (ZXBitMatrix *)blackMatrixWithError:(NSError **)error;
- (ZXBinaryBitmap *)crop:(NSInteger)left top:(NSInteger)top width:(NSInteger)width height:(NSInteger)height;
- (ZXBinaryBitmap *)rotateCounterClockwise;
- (ZXBinaryBitmap *)rotateCounterClockwise45;

@end
