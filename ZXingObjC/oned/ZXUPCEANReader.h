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

#import "ZXBarcodeFormat.h"
#import "ZXOneDReader.h"

/**
 * Encapsulates functionality and implementation that is common to UPC and EAN families
 * of one-dimensional barcodes.
 */

typedef enum {
	UPC_EAN_PATTERNS_L_PATTERNS = 0,
	UPC_EAN_PATTERNS_L_AND_G_PATTERNS
} UPC_EAN_PATTERNS;

#define START_END_PATTERN_LEN 3
extern const NSInteger START_END_PATTERN[];
#define MIDDLE_PATTERN_LEN 5
extern const NSInteger MIDDLE_PATTERN[];
#define L_PATTERNS_LEN 10
#define L_PATTERNS_SUB_LEN 4
extern const NSInteger L_PATTERNS[][4];
extern const NSInteger L_AND_G_PATTERNS[][4];

@class ZXDecodeHints, ZXEANManufacturerOrgSupport, ZXResult, ZXUPCEANExtensionSupport;

@interface ZXUPCEANReader : ZXOneDReader

+ (NSRange)findStartGuardPattern:(ZXBitArray *)row error:(NSError **)error;
- (ZXBarcodeFormat)barcodeFormat;
- (BOOL)checkChecksum:(NSString *)s error:(NSError **)error;
+ (BOOL)checkStandardUPCEANChecksum:(NSString *)s;
+ (NSInteger)decodeDigit:(ZXBitArray *)row counters:(NSInteger[])counters countersLen:(NSInteger)countersLen rowOffset:(NSInteger)rowOffset patternType:(UPC_EAN_PATTERNS)patternType error:(NSError **)error;
- (NSRange)decodeEnd:(ZXBitArray *)row endStart:(NSInteger)endStart error:(NSError **)error;
- (NSInteger)decodeMiddle:(ZXBitArray *)row startRange:(NSRange)startRange result:(NSMutableString *)result error:(NSError **)error;
- (ZXResult *)decodeRow:(NSInteger)rowNumber row:(ZXBitArray *)row startGuardRange:(NSRange)startGuardRange hints:(ZXDecodeHints *)hints error:(NSError **)error;
+ (NSRange)findGuardPattern:(ZXBitArray *)row rowOffset:(NSInteger)rowOffset whiteFirst:(BOOL)whiteFirst pattern:(NSInteger *)pattern patternLen:(NSInteger)patternLen error:(NSError **)error;
+ (NSRange)findGuardPattern:(ZXBitArray *)row rowOffset:(NSInteger)rowOffset whiteFirst:(BOOL)whiteFirst pattern:(NSInteger *)pattern patternLen:(NSInteger)patternLen counters:(NSInteger *)counters error:(NSError **)error;

@end
