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

#import "ZXDataMatrixDataBlock.h"
#import "ZXDataMatrixVersion.h"
#import "ZXQRCodeVersion.h"

@implementation ZXDataMatrixDataBlock

- (id)initWithNumDataCodewords:(NSInteger)numDataCodewords codewords:(NSMutableArray *)codewords {
  if (self = [super init]) {
    _numDataCodewords = numDataCodewords;
    _codewords = codewords;
  }

  return self;
}

/**
 * When Data Matrix Codes use multiple data blocks, they actually interleave the bytes of each of them.
 * That is, the first byte of data block 1 to n is written, then the second bytes, and so on. This
 * method will separate the data into original blocks.
 */
+ (NSArray *)dataBlocks:(NSArray *)rawCodewords version:(ZXDataMatrixVersion *)version {
  ZXDataMatrixECBlocks *ecBlocks = version.ecBlocks;

  NSInteger totalBlocks = 0;
  NSArray *ecBlockArray = ecBlocks.ecBlocks;
  for (ZXDataMatrixECB *ecBlock in ecBlockArray) {
    totalBlocks += ecBlock.count;
  }

  NSMutableArray *result = [NSMutableArray arrayWithCapacity:totalBlocks];
  NSInteger numResultBlocks = 0;
  for (ZXDataMatrixECB *ecBlock in ecBlockArray) {
    for (NSInteger i = 0; i < ecBlock.count; i++) {
      NSInteger numDataCodewords = ecBlock.dataCodewords;
      NSInteger numBlockCodewords = ecBlocks.ecCodewords + numDataCodewords;
      NSMutableArray *tempCodewords = [NSMutableArray arrayWithCapacity:numBlockCodewords];
      for (NSInteger j = 0; j < numBlockCodewords; j++) {
        [tempCodewords addObject:@0];
      }
      [result addObject:[[ZXDataMatrixDataBlock alloc] initWithNumDataCodewords:numDataCodewords codewords:tempCodewords]];
      numResultBlocks++;
    }
  }

  NSInteger longerBlocksTotalCodewords = [[result[0] codewords] count];
  NSInteger longerBlocksNumDataCodewords = longerBlocksTotalCodewords - ecBlocks.ecCodewords;
  NSInteger shorterBlocksNumDataCodewords = longerBlocksNumDataCodewords - 1;
  NSInteger rawCodewordsOffset = 0;
  for (NSInteger i = 0; i < shorterBlocksNumDataCodewords; i++) {
    for (NSInteger j = 0; j < numResultBlocks; j++) {
      [result[j] codewords][i] = rawCodewords[rawCodewordsOffset++];
    }
  }

  BOOL specialVersion = version.versionNumber == 24;
  NSInteger numLongerBlocks = specialVersion ? 8 : numResultBlocks;
  for (NSInteger j = 0; j < numLongerBlocks; j++) {
    [result[j] codewords][longerBlocksNumDataCodewords - 1] = rawCodewords[rawCodewordsOffset++];
  }

  NSInteger max = [[result[0] codewords] count];
  for (NSInteger i = longerBlocksNumDataCodewords; i < max; i++) {
    for (NSInteger j = 0; j < numResultBlocks; j++) {
      NSInteger iOffset = specialVersion && j > 7 ? i - 1 : i;
      [result[j] codewords][iOffset] = rawCodewords[rawCodewordsOffset++];
    }
  }

  if (rawCodewordsOffset != [rawCodewords count]) {
    [NSException raise:NSInvalidArgumentException format:@"Codewords size mismatch"];
  }
  return result;
}

@end
