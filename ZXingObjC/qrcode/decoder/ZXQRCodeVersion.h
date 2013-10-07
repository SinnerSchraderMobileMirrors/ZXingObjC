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
 * Encapsulates a set of error-correction blocks in one symbol version. Most versions will
 * use blocks of differing sizes within one version, so, this encapsulates the parameters for
 * each set of blocks. It also holds the number of error-correction codewords per block since it
 * will be the same across all blocks within one version.
 */

@class ZXQRCodeECB;

@interface ZXQRCodeECBlocks : NSObject

@property (nonatomic, assign, readonly) NSInteger ecCodewordsPerBlock;
@property (nonatomic, assign, readonly) NSInteger numBlocks;
@property (nonatomic, assign, readonly) NSInteger totalECCodewords;
@property (nonatomic, strong, readonly) NSArray *ecBlocks;

- (id)initWithEcCodewordsPerBlock:(NSInteger)ecCodewordsPerBlock ecBlocks:(ZXQRCodeECB *)ecBlocks;
- (id)initWithEcCodewordsPerBlock:(NSInteger)ecCodewordsPerBlock ecBlocks1:(ZXQRCodeECB *)ecBlocks1 ecBlocks2:(ZXQRCodeECB *)ecBlocks2;
+ (ZXQRCodeECBlocks *)ecBlocksWithEcCodewordsPerBlock:(NSInteger)ecCodewordsPerBlock ecBlocks:(ZXQRCodeECB *)ecBlocks;
+ (ZXQRCodeECBlocks *)ecBlocksWithEcCodewordsPerBlock:(NSInteger)ecCodewordsPerBlock ecBlocks1:(ZXQRCodeECB *)ecBlocks1 ecBlocks2:(ZXQRCodeECB *)ecBlocks2;

@end

/**
 * Encapsualtes the parameters for one error-correction block in one symbol version.
 * This includes the number of data codewords, and the number of times a block with these
 * parameters is used consecutively in the QR code version's format.
 */

@interface ZXQRCodeECB : NSObject

@property (nonatomic, assign, readonly) NSInteger count;
@property (nonatomic, assign, readonly) NSInteger dataCodewords;

- (id)initWithCount:(NSInteger)count dataCodewords:(NSInteger)dataCodewords;
+ (ZXQRCodeECB *)ecbWithCount:(NSInteger)count dataCodewords:(NSInteger)dataCodewords;

@end

/**
 * See ISO 18004:2006 Annex D
 */

@class ZXErrorCorrectionLevel, ZXBitMatrix;

@interface ZXQRCodeVersion : NSObject

@property (nonatomic, assign, readonly) NSInteger versionNumber;
@property (nonatomic, strong, readonly) NSArray *alignmentPatternCenters;
@property (nonatomic, strong, readonly) NSArray *ecBlocks;
@property (nonatomic, assign, readonly) NSInteger totalCodewords;
@property (nonatomic, assign, readonly) NSInteger dimensionForVersion;

- (ZXQRCodeECBlocks *)ecBlocksForLevel:(ZXErrorCorrectionLevel *)ecLevel;
+ (ZXQRCodeVersion *)provisionalVersionForDimension:(NSInteger)dimension;
+ (ZXQRCodeVersion *)versionForNumber:(NSInteger)versionNumber;
+ (ZXQRCodeVersion *)decodeVersionInformation:(NSInteger)versionBits;
- (ZXBitMatrix *)buildFunctionPattern;

@end
