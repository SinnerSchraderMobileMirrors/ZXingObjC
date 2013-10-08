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

extern NSInteger ZX_DEFAULT_AZTEC_EC_PERCENT;

@class ZXAztecCode, ZXBitArray, ZXGenericGF;

@interface ZXAztecEncoder : NSObject

+ (ZXAztecCode *)encode:(int8_t *)data len:(NSUInteger)len;
+ (ZXAztecCode *)encode:(int8_t *)data len:(NSUInteger)len minECCPercent:(NSInteger)minECCPercent;
+ (void)drawBullsEye:(ZXBitMatrix *)matrix center:(NSInteger)center size:(NSInteger)size;
+ (ZXBitArray *)generateModeMessageCompact:(BOOL)compact layers:(NSInteger)layers messageSizeInWords:(NSInteger)messageSizeInWords;
+ (void)drawModeMessage:(ZXBitMatrix *)matrix compact:(BOOL)compact matrixSize:(NSInteger)matrixSize modeMessage:(ZXBitArray *)modeMessage;
+ (ZXBitArray *)generateCheckWords:(ZXBitArray *)stuffedBits totalSymbolBits:(NSInteger)totalSymbolBits wordSize:(NSInteger)wordSize;
+ (void)bitsToWords:(ZXBitArray *)stuffedBits wordSize:(NSInteger)wordSize totalWords:(NSInteger)totalWords message:(int32_t *)message;
+ (ZXGenericGF *)getGF:(NSInteger)wordSize;
+ (ZXBitArray *)stuffBits:(ZXBitArray *)bits wordSize:(NSInteger)wordSize;
+ (ZXBitArray *)highLevelEncode:(int8_t *)data len:(NSUInteger)len;
+ (void)outputWord:(ZXBitArray *)bits mode:(NSInteger)mode value:(int8_t)value;

@end
