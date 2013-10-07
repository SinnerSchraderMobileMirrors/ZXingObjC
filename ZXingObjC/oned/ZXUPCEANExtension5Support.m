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
#import "ZXBitArray.h"
#import "ZXErrors.h"
#import "ZXResult.h"
#import "ZXResultMetadataType.h"
#import "ZXResultPoint.h"
#import "ZXUPCEANExtension5Support.h"
#import "ZXUPCEANReader.h"

const NSInteger CHECK_DIGIT_ENCODINGS[10] = {
  0x18, 0x14, 0x12, 0x11, 0x0C, 0x06, 0x03, 0x0A, 0x09, 0x05
};

@implementation ZXUPCEANExtension5Support

- (ZXResult *)decodeRow:(NSInteger)rowNumber row:(ZXBitArray *)row extensionStartRange:(NSRange)extensionStartRange error:(NSError **)error {
  NSMutableString *resultString = [NSMutableString string];
  NSInteger end = [self decodeMiddle:row startRange:extensionStartRange result:resultString error:error];
  if (end == -1) {
    return nil;
  }

  NSMutableDictionary *extensionData = [self parseExtensionString:resultString];

  ZXResult *extensionResult = [[ZXResult alloc] initWithText:resultString
                                                     rawBytes:nil
                                                       length:0
                                                 resultPoints:@[[[ZXResultPoint alloc] initWithX:(extensionStartRange.location + NSMaxRange(extensionStartRange)) / 2.0f y:rowNumber],
                                                                [[ZXResultPoint alloc] initWithX:end y:rowNumber]]
                                                       format:kBarcodeFormatUPCEANExtension];
  if (extensionData != nil) {
    [extensionResult putAllMetadata:extensionData];
  }
  return extensionResult;
}

- (NSInteger)decodeMiddle:(ZXBitArray *)row startRange:(NSRange)startRange result:(NSMutableString *)result error:(NSError **)error {
  const NSInteger countersLen = 4;
  NSInteger counters[countersLen];
  memset(counters, 0, countersLen * sizeof(NSInteger));

  NSInteger end = [row size];
  NSInteger rowOffset = NSMaxRange(startRange);

  NSInteger lgPatternFound = 0;

  for (NSInteger x = 0; x < 5 && rowOffset < end; x++) {
    NSInteger bestMatch = [ZXUPCEANReader decodeDigit:row counters:counters countersLen:countersLen rowOffset:rowOffset patternType:UPC_EAN_PATTERNS_L_AND_G_PATTERNS error:error];
    if (bestMatch == -1) {
      return -1;
    }
    [result appendFormat:@"%C", (unichar)('0' + bestMatch % 10)];
    for (NSInteger i = 0; i < countersLen; i++) {
      rowOffset += counters[i];
    }
    if (bestMatch >= 10) {
      lgPatternFound |= 1 << (4 - x);
    }
    if (x != 4) {
      rowOffset = [row nextSet:rowOffset];
      rowOffset = [row nextUnset:rowOffset];
    }
  }

  if (result.length != 5) {
    if (error) *error = NotFoundErrorInstance();
    return -1;
  }

  NSInteger checkDigit = [self determineCheckDigit:lgPatternFound];
  if (checkDigit == -1) {
    if (error) *error = NotFoundErrorInstance();
    return -1;
  } else if ([self extensionChecksum:result] != checkDigit) {
    if (error) *error = NotFoundErrorInstance();
    return -1;
  }

  return rowOffset;
}

- (NSInteger)extensionChecksum:(NSString *)s {
  NSInteger length = [s length];
  NSInteger sum = 0;
  for (NSInteger i = length - 2; i >= 0; i -= 2) {
    sum += (NSInteger)[s characterAtIndex:i] - (NSInteger)'0';
  }
  sum *= 3;
  for (NSInteger i = length - 1; i >= 0; i -= 2) {
    sum += (NSInteger)[s characterAtIndex:i] - (NSInteger)'0';
  }
  sum *= 3;
  return sum % 10;
}

- (NSInteger)determineCheckDigit:(NSInteger)lgPatternFound {
  for (NSInteger d = 0; d < 10; d++) {
    if (lgPatternFound == CHECK_DIGIT_ENCODINGS[d]) {
      return d;
    }
  }
  return -1;
}

- (NSMutableDictionary *)parseExtensionString:(NSString *)raw {
  if (raw.length != 5) {
    return nil;
  }
  id value = [self parseExtension5String:raw];
  if (value) {
    return [NSMutableDictionary dictionaryWithObject:value forKey:@(kResultMetadataTypeSuggestedPrice)];
  } else {
    return nil;
  }
}

- (NSString *)parseExtension5String:(NSString *)raw {
  NSString *currency;
  switch ([raw characterAtIndex:0]) {
    case '0':
      currency = @"£";
      break;
    case '5':
      currency = @"$";
      break;
    case '9':
      if ([@"90000" isEqualToString:raw]) {
        return nil;
      }
      if ([@"99991" isEqualToString:raw]) {
        return @"0.00";
      }
      if ([@"99990" isEqualToString:raw]) {
        return @"Used";
      }
      currency = @"";
      break;
    default:
      currency = @"";
      break;
  }
  NSInteger rawAmount = [[raw substringFromIndex:1] intValue];
  NSString *unitsString = [@(rawAmount / 100) stringValue];
  NSInteger hundredths = rawAmount % 100;
  NSString *hundredthsString = hundredths < 10 ?
  [NSString stringWithFormat:@"0%ld", (long)hundredths] : [@(hundredths) stringValue];
  return [NSString stringWithFormat:@"%@%@.%@", currency, unitsString, hundredthsString];
}

@end
