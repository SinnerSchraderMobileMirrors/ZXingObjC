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

#import "ZXAztecCode.h"
#import "ZXAztecEncoder.h"
#import "ZXAztecHighLevelEncoder.h"
#import "ZXBitArray.h"
#import "ZXBitMatrix.h"
#import "ZXByteArray.h"
#import "ZXGenericGF.h"
#import "ZXIntArray.h"
#import "ZXReedSolomonEncoder.h"

const int ZX_AZTEC_DEFAULT_EC_PERCENT = 33; // default minimal percentage of error check words
const int ZX_AZTEC_MAX_NB_BITS = 32;

const int ZX_AZTEC_WORD_SIZE[] = {
  4, 6, 6, 8, 8, 8, 8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
  12, 12, 12, 12, 12, 12, 12, 12, 12, 12
};

@implementation ZXAztecEncoder

+ (ZXAztecCode *)encode:(const int8_t *)data len:(NSUInteger)len {
  return [self encode:data len:len minECCPercent:ZX_AZTEC_DEFAULT_EC_PERCENT];
}

+ (ZXAztecCode *)encode:(const int8_t *)data len:(NSUInteger)len minECCPercent:(int)minECCPercent {
  // High-level encode
  ZXBitArray *bits = [[[ZXAztecHighLevelEncoder alloc] initWithData:data textLength:len] encode];

  // stuff bits and choose symbol size
  int eccBits = bits.size * minECCPercent / 100 + 11;
  int totalSizeBits = bits.size + eccBits;
  BOOL compact;
  int layers;
  int totalBitsInLayer;
  int wordSize = 0;
  ZXBitArray *stuffedBits = nil;
  // We look at the possible table sizes in the order Compact1, Compact2, Compact3,
  // Compact4, Normal4,...  Normal(i) for i < 4 isn't typically used since Compact(i+1)
  // is the same size, but has more data.
  for (int i = 0; ; i++) {
    if (i > ZX_AZTEC_MAX_NB_BITS) {
      @throw [NSException exceptionWithName:@"IllegalArgumentException"
                                     reason:@"Data too large for an Aztec code"
                                   userInfo:nil];
    }
    compact = i <= 3;
    layers = compact ? i + 1 : i;
    totalBitsInLayer = [self totalBitsInLayer:layers compact:compact];
    if (totalSizeBits > totalBitsInLayer) {
      continue;
    }
    // [Re]stuff the bits if this is the first opportunity, or if the
    // wordSize has changed
    if (wordSize != ZX_AZTEC_WORD_SIZE[layers]) {
      wordSize = ZX_AZTEC_WORD_SIZE[layers];
      stuffedBits = [self stuffBits:bits wordSize:wordSize];
    }
    int usableBitsInLayers = totalBitsInLayer - (totalBitsInLayer % wordSize);
    if (stuffedBits.size + eccBits <= usableBitsInLayers) {
      break;
    }
  }

  int messageSizeInWords = stuffedBits.size / wordSize;

  // generate check words
  ZXReedSolomonEncoder *rs = [[ZXReedSolomonEncoder alloc] initWithField:[self getGF:wordSize]];
  int totalWordsInLayer = totalBitsInLayer / wordSize;

  ZXIntArray *messageWords = [self bitsToWords:stuffedBits wordSize:wordSize totalWords:totalWordsInLayer];
  [rs encode:messageWords ecBytes:totalWordsInLayer - messageSizeInWords];

  // convert to bit array and pad in the beginning
  int startPad = totalBitsInLayer % wordSize;
  ZXBitArray *messageBits = [[ZXBitArray alloc] init];
  [messageBits appendBits:0 numBits:startPad];
  for (int i = 0; i < totalWordsInLayer; i++) {
    [messageBits appendBits:messageWords.array[i] numBits:wordSize];
  }

  // generate mode message
  ZXBitArray *modeMessage = [self generateModeMessageCompact:compact layers:layers messageSizeInWords:messageSizeInWords];

  // allocate symbol
  int baseMatrixSize = compact ? 11 + layers * 4 : 14 + layers * 4; // not including alignment lines
  int alignmentMap[baseMatrixSize];
  int matrixSize;
  if (compact) {
    // no alignment marks in compact mode, alignmentMap is a no-op
    matrixSize = baseMatrixSize;
    for (int i = 0; i < baseMatrixSize; i++) {
      alignmentMap[i] = i;
    }
  } else {
    matrixSize = baseMatrixSize + 1 + 2 * ((baseMatrixSize / 2 - 1) / 15);
    int origCenter = baseMatrixSize / 2;
    int center = matrixSize / 2;
    for (int i = 0; i < origCenter; i++) {
      int newOffset = i + i / 15;
      alignmentMap[origCenter - i - 1] = center - newOffset - 1;
      alignmentMap[origCenter + i] = center + newOffset + 1;
    }
  }
  ZXBitMatrix *matrix = [[ZXBitMatrix alloc] initWithDimension:matrixSize];

  // draw data bits
  for (int i = 0, rowOffset = 0; i < layers; i++) {
    int rowSize = compact ? (layers - i) * 4 + 9 : (layers - i) * 4 + 12;
    for (int j = 0; j < rowSize; j++) {
      int columnOffset = j * 2;
      for (int k = 0; k < 2; k++) {
        if ([messageBits get:rowOffset + columnOffset + k]) {
          [matrix setX:alignmentMap[i * 2 + k] y:alignmentMap[i * 2 + j]];
        }
        if ([messageBits get:rowOffset + rowSize * 2 + columnOffset + k]) {
          [matrix setX:alignmentMap[i * 2 + j] y:alignmentMap[baseMatrixSize - 1 - i * 2 - k]];
        }
        if ([messageBits get:rowOffset + rowSize * 4 + columnOffset + k]) {
          [matrix setX:alignmentMap[baseMatrixSize - 1 - i * 2 - k] y:alignmentMap[baseMatrixSize - 1 - i * 2 - j]];
        }
        if ([messageBits get:rowOffset + rowSize * 6 + columnOffset + k]) {
          [matrix setX:alignmentMap[baseMatrixSize - 1 - i * 2 - j] y:alignmentMap[i * 2 + k]];
        }
      }
    }
    rowOffset += rowSize * 8;
  }

  // draw mode message
  [self drawModeMessage:matrix compact:compact matrixSize:matrixSize modeMessage:modeMessage];

  // draw alignment marks
  if (compact) {
    [self drawBullsEye:matrix center:matrixSize / 2 size:5];
  } else {
    [self drawBullsEye:matrix center:matrixSize / 2 size:7];
    for (int i = 0, j = 0; i < baseMatrixSize / 2 - 1; i += 15, j += 16) {
      for (int k = (matrixSize / 2) & 1; k < matrixSize; k += 2) {
        [matrix setX:matrixSize / 2 - j y:k];
        [matrix setX:matrixSize / 2 + j y:k];
        [matrix setX:k y:matrixSize / 2 - j];
        [matrix setX:k y:matrixSize / 2 + j];
      }
    }
  }

  ZXAztecCode *aztec = [[ZXAztecCode alloc] init];
  aztec.compact = compact;
  aztec.size = matrixSize;
  aztec.layers = layers;
  aztec.codeWords = messageSizeInWords;
  aztec.matrix = matrix;
  return aztec;
}

+ (void)drawBullsEye:(ZXBitMatrix *)matrix center:(int)center size:(int)size {
  for (int i = 0; i < size; i += 2) {
    for (int j = center - i; j <= center + i; j++) {
      [matrix setX:j y:center - i];
      [matrix setX:j y:center + i];
      [matrix setX:center - i y:j];
      [matrix setX:center + i y:j];
    }
  }
  [matrix setX:center - size y:center - size];
  [matrix setX:center - size + 1 y:center - size];
  [matrix setX:center - size y:center - size + 1];
  [matrix setX:center + size y:center - size];
  [matrix setX:center + size y:center - size + 1];
  [matrix setX:center + size y:center + size - 1];
}

+ (ZXBitArray *)generateModeMessageCompact:(BOOL)compact layers:(int)layers messageSizeInWords:(int)messageSizeInWords {
  ZXBitArray *modeMessage = [[ZXBitArray alloc] init];
  if (compact) {
    [modeMessage appendBits:layers - 1 numBits:2];
    [modeMessage appendBits:messageSizeInWords - 1 numBits:6];
    modeMessage = [self generateCheckWords:modeMessage totalBits:28 wordSize:4];
  } else {
    [modeMessage appendBits:layers - 1 numBits:5];
    [modeMessage appendBits:messageSizeInWords - 1 numBits:11];
    modeMessage = [self generateCheckWords:modeMessage totalBits:40 wordSize:4];
  }
  return modeMessage;
}

+ (void)drawModeMessage:(ZXBitMatrix *)matrix compact:(BOOL)compact matrixSize:(int)matrixSize modeMessage:(ZXBitArray *)modeMessage {
  int center = matrixSize / 2;
  if (compact) {
    for (int i = 0; i < 7; i++) {
      int offset = center - 3 + i;
      if ([modeMessage get:i]) {
        [matrix setX:offset y:center - 5];
      }
      if ([modeMessage get:i + 7]) {
        [matrix setX:center + 5 y:offset];
      }
      if ([modeMessage get:20 - i]) {
        [matrix setX:offset y:center + 5];
      }
      if ([modeMessage get:27 - i]) {
        [matrix setX:center - 5 y:offset];
      }
    }
  } else {
    for (int i = 0; i < 10; i++) {
      int offset = center - 5 + i + i / 5;
      if ([modeMessage get:i]) {
        [matrix setX:offset y:center - 7];
      }
      if ([modeMessage get:i + 10]) {
        [matrix setX:center + 7 y:offset];
      }
      if ([modeMessage get:29 - i]) {
        [matrix setX:offset y:center + 7];
      }
      if ([modeMessage get:39 - i]) {
        [matrix setX:center - 7 y:offset];
      }
    }
  }
}

+ (ZXBitArray *)generateCheckWords:(ZXBitArray *)stuffedBits totalBits:(int)totalBits wordSize:(int)wordSize {
  // stuffedBits is guaranteed to be a multiple of the wordSize, so no padding needed
  int messageSizeInWords = stuffedBits.size / wordSize;
  ZXReedSolomonEncoder *rs = [[ZXReedSolomonEncoder alloc] initWithField:[self getGF:wordSize]];
  int totalWords = totalBits / wordSize;

  ZXIntArray *messageWords = [self bitsToWords:stuffedBits wordSize:wordSize totalWords:totalWords];
  [rs encode:messageWords ecBytes:totalWords - messageSizeInWords];
  int startPad = totalBits % wordSize;
  ZXBitArray *messageBits = [[ZXBitArray alloc] init];
  [messageBits appendBits:0 numBits:startPad];
  for (int i = 0; i < totalWords; i++) {
    [messageBits appendBits:messageWords.array[i] numBits:wordSize];
  }
  return messageBits;
}

+ (ZXIntArray *)bitsToWords:(ZXBitArray *)stuffedBits wordSize:(int)wordSize totalWords:(int)totalWords {
  ZXIntArray *message = [[ZXIntArray alloc] initWithLength:totalWords];
  int i;
  int n;
  for (i = 0, n = stuffedBits.size / wordSize; i < n; i++) {
    int32_t value = 0;
    for (int j = 0; j < wordSize; j++) {
      value |= [stuffedBits get:i * wordSize + j] ? (1 << (wordSize - j - 1)) : 0;
    }
    message.array[i] = value;
  }
  return message;
}

+ (ZXGenericGF *)getGF:(int)wordSize {
  switch (wordSize) {
    case 4:
      return [ZXGenericGF AztecParam];
    case 6:
      return [ZXGenericGF AztecData6];
    case 8:
      return [ZXGenericGF AztecData8];
    case 10:
      return [ZXGenericGF AztecData10];
    case 12:
      return [ZXGenericGF AztecData12];
    default:
      return nil;
  }
}

+ (ZXBitArray *)stuffBits:(ZXBitArray *)bits wordSize:(int)wordSize {
  ZXBitArray *arrayOut = [[ZXBitArray alloc] init];

  // 1. stuff the bits
  int n = bits.size;
  int mask = (1 << wordSize) - 2;
  for (int i = 0; i < n; i += wordSize) {
    int word = 0;
    for (int j = 0; j < wordSize; j++) {
      if (i + j >= n || [bits get:i + j]) {
        word |= 1 << (wordSize - 1 - j);
      }
    }
    if ((word & mask) == mask) {
      [arrayOut appendBits:word & mask numBits:wordSize];
      i--;
    } else if ((word & mask) == 0) {
      [arrayOut appendBits:word | 1 numBits:wordSize];
      i--;
    } else {
      [arrayOut appendBits:word numBits:wordSize];
    }
  }

  return arrayOut;
}

+ (int)totalBitsInLayer:(int)layers compact:(BOOL)compact {
  return ((compact ? 88 : 112) + 16 * layers) * layers;
}

@end
