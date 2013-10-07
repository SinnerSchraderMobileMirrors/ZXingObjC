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

#import "ZXITFReader.h"
#import "ZXITFWriter.h"

const NSInteger ITF_WRITER_START_PATTERN_LEN = 4;
const NSInteger ITF_WRITER_START_PATTERN[ITF_WRITER_START_PATTERN_LEN] = {1, 1, 1, 1};

const NSInteger ITF_WRITER_END_PATTERN_LEN = 3;
const NSInteger ITF_WRITER_END_PATTERN[ITF_WRITER_END_PATTERN_LEN] = {3, 1, 1};

@implementation ZXITFWriter

- (ZXBitMatrix *)encode:(NSString *)contents format:(ZXBarcodeFormat)format width:(NSInteger)width height:(NSInteger)height hints:(ZXEncodeHints *)hints error:(NSError **)error {
  if (format != kBarcodeFormatITF) {
    [NSException raise:NSInvalidArgumentException format:@"Can only encode ITF"];
  }

  return [super encode:contents format:format width:width height:height hints:hints error:error];
}

- (BOOL *)encode:(NSString *)contents length:(NSInteger *)pLength {
  NSInteger length = [contents length];
  if (length % 2 != 0) {
    [NSException raise:NSInvalidArgumentException format:@"The length of the input should be even"];
  }
  if (length > 80) {
    [NSException raise:NSInvalidArgumentException format:@"Requested contents should be less than 80 digits long, but got %ld", (long)length];
  }

  NSInteger resultLen = 9 + 9 * length;
  if (pLength) *pLength = resultLen;
  BOOL *result = (BOOL *)malloc(resultLen * sizeof(BOOL));
  NSInteger pos = [super appendPattern:result pos:0 pattern:(NSInteger *)ITF_WRITER_START_PATTERN patternLen:ITF_WRITER_START_PATTERN_LEN startColor:TRUE];
  for (NSInteger i = 0; i < length; i += 2) {
    NSInteger one = [[contents substringWithRange:NSMakeRange(i, 1)] intValue];
    NSInteger two = [[contents substringWithRange:NSMakeRange(i + 1, 1)] intValue];
    const NSInteger encodingLen = 18;
    NSInteger encoding[encodingLen];
    memset(encoding, 0, encodingLen * sizeof(NSInteger));
    for (NSInteger j = 0; j < 5; j++) {
      encoding[j << 1] = PATTERNS[one][j];
      encoding[(j << 1) + 1] = PATTERNS[two][j];
    }
    pos += [super appendPattern:result pos:pos pattern:encoding patternLen:encodingLen startColor:TRUE];
  }
  [super appendPattern:result pos:pos pattern:(NSInteger *)ITF_WRITER_END_PATTERN patternLen:ITF_WRITER_END_PATTERN_LEN startColor:TRUE];

  return result;
}

@end
