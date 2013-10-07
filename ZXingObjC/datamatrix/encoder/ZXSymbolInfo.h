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

/**
 * Symbol info table for DataMatrix.
 */

@class ZXDimension, ZXSymbolShapeHint;

@interface ZXSymbolInfo : NSObject

@property (nonatomic, assign) BOOL rectangular;
@property (nonatomic, assign) NSInteger errorCodewords;
@property (nonatomic, assign) NSInteger dataCapacity;
@property (nonatomic, assign) NSInteger dataRegions;
@property (nonatomic, assign) NSInteger matrixWidth;
@property (nonatomic, assign) NSInteger matrixHeight;
@property (nonatomic, assign) NSInteger rsBlockData;
@property (nonatomic, assign) NSInteger rsBlockError;

/**
 * Overrides the symbol info set used by this class. Used for testing purposes.
 */
+ (void)overrideSymbolSet:(NSArray *)override;
+ (NSArray *)prodSymbols;
- (id)initWithRectangular:(BOOL)rectangular dataCapacity:(NSInteger)dataCapacity errorCodewords:(NSInteger)errorCodewords
              matrixWidth:(NSInteger)matrixWidth matrixHeight:(NSInteger)matrixHeight dataRegions:(NSInteger)dataRegions;
- (id)initWithRectangular:(BOOL)rectangular dataCapacity:(NSInteger)dataCapacity errorCodewords:(NSInteger)errorCodewords
              matrixWidth:(NSInteger)matrixWidth matrixHeight:(NSInteger)matrixHeight dataRegions:(NSInteger)dataRegions
              rsBlockData:(NSInteger)rsBlockData rsBlockError:(NSInteger)rsBlockError;
+ (ZXSymbolInfo *)lookup:(NSInteger)dataCodewords;
+ (ZXSymbolInfo *)lookup:(NSInteger)dataCodewords shape:(ZXSymbolShapeHint *)shape;
+ (ZXSymbolInfo *)lookup:(NSInteger)dataCodewords allowRectangular:(BOOL)allowRectangular fail:(BOOL)fail;
+ (ZXSymbolInfo *)lookup:(NSInteger)dataCodewords shape:(ZXSymbolShapeHint *)shape fail:(BOOL)fail;
+ (ZXSymbolInfo *)lookup:(NSInteger)dataCodewords shape:(ZXSymbolShapeHint *)shape minSize:(ZXDimension *)minSize
                 maxSize:(ZXDimension *)maxSize fail:(BOOL)fail;
- (NSInteger)horizontalDataRegions;
- (NSInteger)verticalDataRegions;
- (NSInteger)symbolDataWidth;
- (NSInteger)symbolDataHeight;
- (NSInteger)symbolWidth;
- (NSInteger)symbolHeight;
- (NSInteger)codewordCount;
- (NSInteger)interleavedBlockCount;
- (NSInteger)dataLengthForInterleavedBlock:(NSInteger)index;
- (NSInteger)errorLengthForInterleavedBlock:(NSInteger)index;

@end
