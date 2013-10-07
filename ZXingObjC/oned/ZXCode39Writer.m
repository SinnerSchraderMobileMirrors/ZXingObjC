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

#import "ZXBitMatrix.h"
#import "ZXCode39Reader.h"
#import "ZXCode39Writer.h"

#define ZX_CODE39_WHITELEN 1

@implementation ZXCode39Writer

- (ZXBitMatrix *)encode:(NSString *)contents format:(ZXBarcodeFormat)format width:(NSInteger)width height:(NSInteger)height hints:(ZXEncodeHints *)hints error:(NSError **)error {
  if (format != kBarcodeFormatCode39) {
    [NSException raise:NSInvalidArgumentException 
                format:@"Can only encode CODE_39."];
  }
  return [super encode:contents format:format width:width height:height hints:hints error:error];
}

- (BOOL *)encode:(NSString *)contents length:(NSInteger *)pLength {
  NSInteger length = [contents length];
  if (length > 80) {
    [NSException raise:NSInvalidArgumentException 
                format:@"Requested contents should be less than 80 digits long, but got %ld", (long)length];
  }

  const NSInteger widthsLengh = 9;
  NSInteger widths[widthsLengh];
  memset(widths, 0, widthsLengh * sizeof(NSInteger));

  NSInteger codeWidth = 24 + 1 + length;
  for (NSInteger i = 0; i < length; i++) {
    NSUInteger indexInString = [CODE39_ALPHABET_STRING rangeOfString:[contents substringWithRange:NSMakeRange(i, 1)]].location;
    [self toIntArray:CODE39_CHARACTER_ENCODINGS[indexInString] toReturn:widths];
    for (NSInteger j = 0; j < widthsLengh; j++) {
      codeWidth += widths[j];
    }
  }

  if (pLength) *pLength = codeWidth;
  BOOL *result = (BOOL *)malloc(codeWidth * sizeof(BOOL));
  [self toIntArray:CODE39_CHARACTER_ENCODINGS[39] toReturn:widths];
  NSInteger pos = [super appendPattern:result pos:0 pattern:widths patternLen:widthsLengh startColor:TRUE];

  const NSInteger narrowWhiteLen = ZX_CODE39_WHITELEN;
  NSInteger narrowWhite[ZX_CODE39_WHITELEN] = {1};

  pos += [super appendPattern:result pos:pos pattern:narrowWhite patternLen:narrowWhiteLen startColor:FALSE];

  for (NSInteger i = length - 1; i >= 0; i--) {
    NSUInteger indexInString = [CODE39_ALPHABET_STRING rangeOfString:[contents substringWithRange:NSMakeRange(i, 1)]].location;
    [self toIntArray:CODE39_CHARACTER_ENCODINGS[indexInString] toReturn:widths];
    pos += [super appendPattern:result pos:pos pattern:widths patternLen:widthsLengh startColor:TRUE];
    pos += [super appendPattern:result pos:pos pattern:narrowWhite patternLen:narrowWhiteLen startColor:FALSE];
  }

  [self toIntArray:CODE39_CHARACTER_ENCODINGS[39] toReturn:widths];
  pos += [super appendPattern:result pos:pos pattern:widths patternLen:widthsLengh startColor:TRUE];
  return result;
}

- (void)toIntArray:(NSInteger)a toReturn:(NSInteger[])toReturn {
  for (NSInteger i = 0; i < 9; i++) {
    NSInteger temp = a & (1 << i);
    toReturn[i] = temp == 0 ? 1 : 2;
  }
}

@end
