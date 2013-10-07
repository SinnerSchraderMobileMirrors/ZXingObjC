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

@class ZXDimension, ZXSymbolInfo, ZXSymbolShapeHint;

@interface ZXEncoderContext : NSObject

@property (nonatomic, copy) NSMutableString *codewords;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) NSInteger newEncoding;
@property (nonatomic, assign) NSInteger pos;
@property (nonatomic, assign) NSInteger skipAtEnd;
@property (nonatomic, strong) ZXSymbolShapeHint *symbolShape;
@property (nonatomic, strong) ZXSymbolInfo *symbolInfo;

- (id)initWithMessage:(NSString *)msg;
- (void)setSizeConstraints:(ZXDimension *)minSize maxSize:(ZXDimension *)maxSize;
- (void)setSkipAtEnd:(NSInteger)count;
- (unichar)currentChar;
- (unichar)current;
- (void)writeCodewords:(NSString *)codewords;
- (void)writeCodeword:(unichar)codeword;
- (NSInteger)codewordCount;
- (void)signalEncoderChange:(NSInteger)encoding;
- (void)resetEncoderSignal;
- (BOOL)hasMoreCharacters;
- (NSInteger)totalMessageCharCount;
- (NSInteger)remainingCharacters;
- (void)updateSymbolInfo;
- (void)updateSymbolInfoWithLength:(NSInteger)len;
- (void)resetSymbolInfo;

@end
