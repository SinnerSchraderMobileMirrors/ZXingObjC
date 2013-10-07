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

@class ZXBitArray, ZXEncodeHints, ZXErrorCorrectionLevel, ZXMode, ZXQRCode, ZXQRCodeVersion;

extern const NSStringEncoding DEFAULT_BYTE_MODE_ENCODING;

@interface ZXEncoder : NSObject

+ (ZXQRCode *)encode:(NSString *)content ecLevel:(ZXErrorCorrectionLevel *)ecLevel error:(NSError **)error;
+ (ZXQRCode *)encode:(NSString *)content ecLevel:(ZXErrorCorrectionLevel *)ecLevel hints:(ZXEncodeHints *)hints error:(NSError **)error;
+ (NSInteger)alphanumericCode:(NSInteger)code;
+ (ZXMode *)chooseMode:(NSString *)content;
+ (BOOL)terminateBits:(NSInteger)numDataBytes bits:(ZXBitArray *)bits error:(NSError **)error;
+ (BOOL)numDataBytesAndNumECBytesForBlockID:(NSInteger)numTotalBytes numDataBytes:(NSInteger)numDataBytes numRSBlocks:(NSInteger)numRSBlocks blockID:(NSInteger)blockID numDataBytesInBlock:(NSInteger[])numDataBytesInBlock numECBytesInBlock:(NSInteger[])numECBytesInBlock error:(NSError **)error;
+ (ZXBitArray *)interleaveWithECBytes:(ZXBitArray *)bits numTotalBytes:(NSInteger)numTotalBytes numDataBytes:(NSInteger)numDataBytes numRSBlocks:(NSInteger)numRSBlocks error:(NSError **)error;
+ (int8_t *)generateECBytes:(int8_t *)dataBytes numDataBytes:(NSInteger)numDataBytes numEcBytesInBlock:(NSInteger)numEcBytesInBlock;
+ (void)appendModeInfo:(ZXMode *)mode bits:(ZXBitArray *)bits;
+ (BOOL)appendLengthInfo:(NSInteger)numLetters version:(ZXQRCodeVersion *)version mode:(ZXMode *)mode bits:(ZXBitArray *)bits error:(NSError **)error;
+ (BOOL)appendBytes:(NSString *)content mode:(ZXMode *)mode bits:(ZXBitArray *)bits encoding:(NSStringEncoding)encoding error:(NSError **)error;
+ (void)appendNumericBytes:(NSString *)content bits:(ZXBitArray *)bits;
+ (BOOL)appendAlphanumericBytes:(NSString *)content bits:(ZXBitArray *)bits error:(NSError **)error;
+ (void)append8BitBytes:(NSString *)content bits:(ZXBitArray *)bits encoding:(NSStringEncoding)encoding;
+ (BOOL)appendKanjiBytes:(NSString *)content bits:(ZXBitArray *)bits error:(NSError **)error;

@end
