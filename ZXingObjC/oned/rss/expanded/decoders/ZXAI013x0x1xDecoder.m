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

#import "ZXAI013x0x1xDecoder.h"
#import "ZXBitArray.h"
#import "ZXErrors.h"
#import "ZXGeneralAppIdDecoder.h"

NSInteger const AI013x0x1x_HEADER_SIZE = 7 + 1;
NSInteger const AI013x0x1x_WEIGHT_SIZE = 20;
NSInteger const AI013x0x1x_DATE_SIZE = 16;

@interface ZXAI013x0x1xDecoder ()

@property (nonatomic, copy) NSString *dateCode;
@property (nonatomic, copy) NSString *firstAIdigits;

@end

@implementation ZXAI013x0x1xDecoder

- (id)initWithInformation:(ZXBitArray *)information firstAIdigits:(NSString *)firstAIdigits dateCode:(NSString *)dateCode {
  if (self = [super initWithInformation:information]) {
    _dateCode = dateCode;
    _firstAIdigits = firstAIdigits;
  }

  return self;
}

- (NSString *)parseInformationWithError:(NSError **)error {
  if (self.information.size != AI013x0x1x_HEADER_SIZE + GTIN_SIZE + AI013x0x1x_WEIGHT_SIZE + AI013x0x1x_DATE_SIZE) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }
  NSMutableString *buf = [NSMutableString string];
  [self encodeCompressedGtin:buf currentPos:AI013x0x1x_HEADER_SIZE];
  [self encodeCompressedWeight:buf currentPos:AI013x0x1x_HEADER_SIZE + GTIN_SIZE weightSize:AI013x0x1x_WEIGHT_SIZE];
  [self encodeCompressedDate:buf currentPos:AI013x0x1x_HEADER_SIZE + GTIN_SIZE + AI013x0x1x_WEIGHT_SIZE];
  return buf;
}

- (void)encodeCompressedDate:(NSMutableString *)buf currentPos:(NSInteger)currentPos {
  NSInteger numericDate = [self.generalDecoder extractNumericValueFromBitArray:currentPos bits:AI013x0x1x_DATE_SIZE];
  if (numericDate == 38400) {
    return;
  }
  [buf appendFormat:@"(%@)", self.dateCode];
  NSInteger day = numericDate % 32;
  numericDate /= 32;
  NSInteger month = numericDate % 12 + 1;
  numericDate /= 12;
  NSInteger year = numericDate;
  if (year / 10 == 0) {
    [buf appendString:@"0"];
  }
  [buf appendFormat:@"%ld", (long)year];
  if (month / 10 == 0) {
    [buf appendString:@"0"];
  }
  [buf appendFormat:@"%ld", (long)month];
  if (day / 10 == 0) {
    [buf appendString:@"0"];
  }
  [buf appendFormat:@"%ld", (long)day];
}

- (void)addWeightCode:(NSMutableString *)buf weight:(NSInteger)weight {
  NSInteger lastAI = weight / 100000;
  [buf appendFormat:@"(%@%ld)", self.firstAIdigits, (long)lastAI];
}

- (NSInteger)checkWeight:(NSInteger)weight {
  return weight % 100000;
}

@end
