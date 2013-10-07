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

#import "ZXErrorCorrectionLevel.h"
#import "ZXQRCodeDataBlock.h"
#import "ZXQRCodeVersion.h"

@implementation ZXQRCodeDataBlock

- (id)initWithNumDataCodewords:(NSInteger)numDataCodewords codewords:(NSMutableArray *)codewords {
  if (self = [super init]) {
    _numDataCodewords = numDataCodewords;
    _codewords = codewords;
  }

  return self;
}

/**
 * When QR Codes use multiple data blocks, they are actually interleaved.
 * That is, the first byte of data block 1 to n is written, then the second bytes, and so on. This
 * method will separate the data into original blocks.
 */
+ (NSArray *)dataBlocks:(NSArray *)rawCodewords version:(ZXQRCodeVersion *)version ecLevel:(ZXErrorCorrectionLevel *)ecLevel {
  if (rawCodewords.count != version.totalCodewords) {
    [NSException raise:NSInvalidArgumentException format:@"Invalid codewords count"];
  }

  ZXQRCodeECBlocks *ecBlocks = [version ecBlocksForLevel:ecLevel];

  NSInteger totalBlocks = 0;
  NSArray *ecBlockArray = ecBlocks.ecBlocks;
  for (ZXQRCodeECB *ecBlock in ecBlockArray) {
    totalBlocks += ecBlock.count;
  }

  NSMutableArray *result = [NSMutableArray arrayWithCapacity:totalBlocks];
  for (ZXQRCodeECB *ecBlock in ecBlockArray) {
    for (NSInteger i = 0; i < ecBlock.count; i++) {
      NSInteger numDataCodewords = ecBlock.dataCodewords;
      NSInteger numBlockCodewords = ecBlocks.ecCodewordsPerBlock + numDataCodewords;
      NSMutableArray *newCodewords = [NSMutableArray arrayWithCapacity:numBlockCodewords];
      for (NSInteger j = 0; j < numBlockCodewords; j++) {
        [newCodewords addObject:[NSNull null]];
      }

      [result addObject:[[ZXQRCodeDataBlock alloc] initWithNumDataCodewords:numDataCodewords codewords:newCodewords]];
    }
  }

  NSInteger shorterBlocksTotalCodewords = [[result[0] codewords] count];
  NSInteger longerBlocksStartAt = [result count] - 1;

  while (longerBlocksStartAt >= 0) {
    NSInteger numCodewords = [[result[longerBlocksStartAt] codewords] count];
    if (numCodewords == shorterBlocksTotalCodewords) {
      break;
    }
    longerBlocksStartAt--;
  }

  longerBlocksStartAt++;
  NSInteger shorterBlocksNumDataCodewords = shorterBlocksTotalCodewords - ecBlocks.ecCodewordsPerBlock;
  NSInteger rawCodewordsOffset = 0;
  NSInteger numResultBlocks = [result count];

  for (NSInteger i = 0; i < shorterBlocksNumDataCodewords; i++) {
    for (NSInteger j = 0; j < numResultBlocks; j++) {
      [result[j] codewords][i] = rawCodewords[rawCodewordsOffset++];
    }
  }

  for (NSInteger j = longerBlocksStartAt; j < numResultBlocks; j++) {
    [result[j] codewords][shorterBlocksNumDataCodewords] = rawCodewords[rawCodewordsOffset++];
  }

  NSInteger max = [[result[0] codewords] count];
  for (NSInteger i = shorterBlocksNumDataCodewords; i < max; i++) {
    for (NSInteger j = 0; j < numResultBlocks; j++) {
      NSInteger iOffset = j < longerBlocksStartAt ? i : i + 1;
      [result[j] codewords][iOffset] = rawCodewords[rawCodewordsOffset++];
    }
  }

  return result;
}

@end
