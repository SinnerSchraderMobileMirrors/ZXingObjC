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
#import "ZXEAN13Reader.h"
#import "ZXEAN13Writer.h"
#import "ZXUPCEANReader.h"

const NSInteger EAN13_CODE_WIDTH = 3 + // start guard
  (7 * 6) + // left bars
  5 + // middle guard
  (7 * 6) + // right bars
  3; // end guard

@implementation ZXEAN13Writer

- (ZXBitMatrix *)encode:(NSString *)contents format:(ZXBarcodeFormat)format width:(NSInteger)width height:(NSInteger)height hints:(ZXEncodeHints *)hints error:(NSError **)error {
  if (format != kBarcodeFormatEan13) {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Can only encode EAN_13, but got %d", format]
                                 userInfo:nil];
  }

  return [super encode:contents format:format width:width height:height hints:hints error:error];
}

- (BOOL *)encode:(NSString *)contents length:(NSInteger *)pLength {
  if ([contents length] != 13) {
    [NSException raise:NSInvalidArgumentException
                format:@"Requested contents should be 13 digits long, but got %ld", (long)[contents length]];
  }

  if (![ZXUPCEANReader checkStandardUPCEANChecksum:contents]) {
    [NSException raise:NSInvalidArgumentException
                format:@"Contents do not pass checksum"];
  }

  NSInteger firstDigit = [[contents substringToIndex:1] intValue];
  NSInteger parities = FIRST_DIGIT_ENCODINGS[firstDigit];
  if (pLength) *pLength = EAN13_CODE_WIDTH;
  BOOL *result = (BOOL *)malloc(EAN13_CODE_WIDTH * sizeof(BOOL));
  memset(result, 0, EAN13_CODE_WIDTH * sizeof(int8_t));
  NSInteger pos = 0;

  pos += [super appendPattern:result pos:pos pattern:(NSInteger *)START_END_PATTERN patternLen:START_END_PATTERN_LEN startColor:TRUE];

  for (NSInteger i = 1; i <= 6; i++) {
    NSInteger digit = [[contents substringWithRange:NSMakeRange(i, 1)] intValue];
    if ((parities >> (6 - i) & 1) == 1) {
      digit += 10;
    }
    pos += [super appendPattern:result pos:pos pattern:(NSInteger *)L_AND_G_PATTERNS[digit] patternLen:L_PATTERNS_SUB_LEN startColor:FALSE];
  }

  pos += [super appendPattern:result pos:pos pattern:(NSInteger *)MIDDLE_PATTERN patternLen:MIDDLE_PATTERN_LEN startColor:FALSE];

  for (NSInteger i = 7; i <= 12; i++) {
    NSInteger digit = [[contents substringWithRange:NSMakeRange(i, 1)] intValue];
    pos += [super appendPattern:result pos:pos pattern:(NSInteger *)L_PATTERNS[digit] patternLen:L_PATTERNS_SUB_LEN startColor:TRUE];
  }
  pos += [super appendPattern:result pos:pos pattern:(NSInteger *)START_END_PATTERN patternLen:START_END_PATTERN_LEN startColor:TRUE];

  return result;
}

@end
