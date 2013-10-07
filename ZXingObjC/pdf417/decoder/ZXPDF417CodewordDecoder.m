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

#import "ZXPDF417CodewordDecoder.h"
#import "ZXPDF417Common.h"

static float ZXPDF417_RATIOS_TABLE[ZXPDF417_SYMBOL_TABLE_LEN][ZXPDF417_BARS_IN_MODULE];

@implementation ZXPDF417CodewordDecoder

+ (void)initialize {
  // Pre-computes the symbol ratio table.
  for (NSInteger i = 0; i < ZXPDF417_SYMBOL_TABLE_LEN; i++) {
    NSInteger currentSymbol = ZXPDF417_SYMBOL_TABLE[i];
    NSInteger currentBit = currentSymbol & 0x1;
    for (NSInteger j = 0; j < ZXPDF417_BARS_IN_MODULE; j++) {
      float size = 0.0f;
      while ((currentSymbol & 0x1) == currentBit) {
        size += 1.0f;
        currentSymbol >>= 1;
      }
      currentBit = currentSymbol & 0x1;
      ZXPDF417_RATIOS_TABLE[i][ZXPDF417_BARS_IN_MODULE - j - 1] = size / ZXPDF417_MODULES_IN_CODEWORD;
    }
  }
}

+ (NSInteger)decodedValue:(NSArray *)moduleBitCount {
  NSInteger decodedValue = [self decodedCodewordValue:[self sampleBitCounts:moduleBitCount]];
  if (decodedValue != -1) {
    return decodedValue;
  }
  return [self closestDecodedValue:moduleBitCount];
}

+ (NSArray *)sampleBitCounts:(NSArray *)moduleBitCount {
  float bitCountSum = [ZXPDF417Common bitCountSum:moduleBitCount];
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:ZXPDF417_BARS_IN_MODULE];
  for (NSInteger i = 0; i < ZXPDF417_BARS_IN_MODULE; i++) {
    [result addObject:@0];
  }

  NSInteger bitCountIndex = 0;
  NSInteger sumPreviousBits = 0;
  for (NSInteger i = 0; i < ZXPDF417_MODULES_IN_CODEWORD; i++) {
    float sampleIndex =
      bitCountSum / (2 * ZXPDF417_MODULES_IN_CODEWORD) +
      (i * bitCountSum) / ZXPDF417_MODULES_IN_CODEWORD;
    if (sumPreviousBits + [moduleBitCount[bitCountIndex] intValue] <= sampleIndex) {
      sumPreviousBits += [moduleBitCount[bitCountIndex] intValue];
      bitCountIndex++;
    }
    result[bitCountIndex] = @([result[bitCountIndex] intValue] + 1);
  }
  return result;
}

+ (NSInteger)decodedCodewordValue:(NSArray *)moduleBitCount {
  NSInteger decodedValue = [self bitValue:moduleBitCount];
  return [ZXPDF417Common codeword:decodedValue] == -1 ? -1 : decodedValue;
}

+ (NSInteger)bitValue:(NSArray *)moduleBitCount {
  long result = 0;
  for (NSInteger i = 0; i < [moduleBitCount count]; i++) {
    for (NSInteger bit = 0; bit < [moduleBitCount[i] intValue]; bit++) {
      result = (result << 1) | (i % 2 == 0 ? 1 : 0);
    }
  }
  return (NSInteger) result;
}

+ (NSInteger)closestDecodedValue:(NSArray *)moduleBitCount {
  NSInteger bitCountSum = [ZXPDF417Common bitCountSum:moduleBitCount];
  float bitCountRatios[ZXPDF417_BARS_IN_MODULE];
  for (NSInteger i = 0; i < ZXPDF417_BARS_IN_MODULE; i++) {
    bitCountRatios[i] = [moduleBitCount[i] intValue] / (float) bitCountSum;
  }
  float bestMatchError = MAXFLOAT;
  NSInteger bestMatch = -1;
  for (NSInteger j = 0; j < ZXPDF417_SYMBOL_TABLE_LEN; j++) {
    float error = 0.0f;
    for (NSInteger k = 0; k < ZXPDF417_BARS_IN_MODULE; k++) {
      float diff = ZXPDF417_RATIOS_TABLE[j][k] - bitCountRatios[k];
      error += diff * diff;
    }
    if (error < bestMatchError) {
      bestMatchError = error;
      bestMatch = ZXPDF417_SYMBOL_TABLE[j];
    }
  }
  return bestMatch;
}

@end
