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

#import "ZXAI01decoder.h"
#import "ZXBitArray.h"
#import "ZXGeneralAppIdDecoder.h"

NSInteger const GTIN_SIZE = 40;

@implementation ZXAI01decoder

- (void)encodeCompressedGtin:(NSMutableString *)buf currentPos:(NSInteger)currentPos {
  [buf appendString:@"(01)"];
  NSInteger initialPosition = [buf length];
  [buf appendString:@"9"];

  [self encodeCompressedGtinWithoutAI:buf currentPos:currentPos initialBufferPosition:initialPosition];
}

- (void)encodeCompressedGtinWithoutAI:(NSMutableString *)buf currentPos:(NSInteger)currentPos initialBufferPosition:(NSInteger)initialBufferPosition {
  for (NSInteger i = 0; i < 4; ++i) {
    NSInteger currentBlock = [self.generalDecoder extractNumericValueFromBitArray:currentPos + 10 * i bits:10];
    if (currentBlock / 100 == 0) {
      [buf appendString:@"0"];
    }
    if (currentBlock / 10 == 0) {
      [buf appendString:@"0"];
    }
    [buf appendFormat:@"%ld", (long)currentBlock];
  }

  [self appendCheckDigit:buf currentPos:initialBufferPosition];
}

- (void)appendCheckDigit:(NSMutableString *)buf currentPos:(NSInteger)currentPos {
  NSInteger checkDigit = 0;
  for (NSInteger i = 0; i < 13; i++) {
    NSInteger digit = [buf characterAtIndex:i + currentPos] - '0';
    checkDigit += (i & 0x01) == 0 ? 3 * digit : digit;
  }

  checkDigit = 10 - (checkDigit % 10);
  if (checkDigit == 10) {
    checkDigit = 0;
  }

  [buf appendFormat:@"%ld", (long)checkDigit];
}

@end
