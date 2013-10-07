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

@interface ZXPDF417Codeword : NSObject

@property (nonatomic, assign, readonly) NSInteger startX;
@property (nonatomic, assign, readonly) NSInteger endX;
@property (nonatomic, assign, readonly) NSInteger bucket;
@property (nonatomic, assign, readonly) NSInteger value;
@property (nonatomic, assign) NSInteger rowNumber;

- (id)initWithStartX:(NSInteger)startX endX:(NSInteger)endX bucket:(NSInteger)bucket value:(NSInteger)value;
- (BOOL)hasValidRowNumber;
- (BOOL)isValidRowNumber:(NSInteger)rowNumber;
- (void)setRowNumberAsRowIndicatorColumn;
- (NSInteger)width;

@end
