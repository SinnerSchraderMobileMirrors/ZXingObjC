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
#import "ZXBitArray.h"
#import "ZXBitMatrix.h"
#import "ZXGenericGF.h"
#import "ZXReedSolomonEncoder.h"

NSInteger ZX_DEFAULT_AZTEC_EC_PERCENT = 33;

const NSInteger TABLE_UPPER  = 0; // 5 bits
const NSInteger TABLE_LOWER  = 1; // 5 bits
const NSInteger TABLE_DIGIT  = 2; // 4 bits
const NSInteger TABLE_MIXED  = 3; // 5 bits
const NSInteger TABLE_PUNCT  = 4; // 5 bits
const NSInteger TABLE_BINARY = 5; // 8 bits

static NSInteger CHAR_MAP[5][256]; // reverse mapping ASCII -> table offset, per table
static NSInteger SHIFT_TABLE[6][6]; // mode shift codes, per table
static NSInteger LATCH_TABLE[6][6]; // mode latch codes, per table

const NSInteger NB_BITS_LEN = 33;
static NSInteger NB_BITS[NB_BITS_LEN]; // total bits per compact symbol for a given number of layers

const NSInteger NB_BITS_COMPACT_LEN = 5;
static NSInteger NB_BITS_COMPACT[NB_BITS_COMPACT_LEN]; // total bits per full symbol for a given number of layers

static NSInteger WORD_SIZE[33] = {
  4, 6, 6, 8, 8, 8, 8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
  12, 12, 12, 12, 12, 12, 12, 12, 12, 12
};

@implementation ZXAztecEncoder

+ (void)initialize {
  CHAR_MAP[TABLE_UPPER][' '] = 1;
  for (NSInteger c = 'A'; c <= 'Z'; c++) {
    CHAR_MAP[TABLE_UPPER][c] = c - 'A' + 2;
  }
  CHAR_MAP[TABLE_LOWER][' '] = 1;
  for (NSInteger c = 'a'; c <= 'z'; c++) {
    CHAR_MAP[TABLE_LOWER][c] = c - 'a' + 2;
  }
  CHAR_MAP[TABLE_DIGIT][' '] = 1;
  for (NSInteger c = '0'; c <= '9'; c++) {
    CHAR_MAP[TABLE_DIGIT][c] = c - '0' + 2;
  }
  CHAR_MAP[TABLE_DIGIT][','] = 12;
  CHAR_MAP[TABLE_DIGIT]['.'] = 13;

  const NSInteger mixedTableLen = 28;
  NSInteger mixedTable[mixedTableLen] = {
    '\0', ' ', '\1', '\2', '\3', '\4', '\5', '\6', '\7', '\b', '\t', '\n', '\13', '\f', '\r',
    '\33', '\34', '\35', '\36', '\37', '@', '\\', '^', '_', '`', '|', '~', '\177'
  };
  for (NSInteger i = 0; i < 28; i++) {
    CHAR_MAP[TABLE_MIXED][mixedTable[i]] = i;
  }
  const NSInteger punctTableLen = 31;
  NSInteger punctTable[punctTableLen] = {
    '\0', '\r', '\0', '\0', '\0', '\0', '!', '\'', '#', '$', '%', '&', '\'', '(', ')', '*', '+',
    ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '[', ']', '{', '}'
  };
  for (NSInteger i = 0; i < punctTableLen; i++) {
    if (punctTable[i] > 0) {
      CHAR_MAP[TABLE_PUNCT][punctTable[i]] = i;
    }
  }
  for (NSInteger i = 0; i < 6; i++) {
    for (NSInteger j = 0; j < 6; j++) {
      SHIFT_TABLE[i][j] = -1;
      LATCH_TABLE[i][j] = -1;
    }
  }
  SHIFT_TABLE[TABLE_UPPER][TABLE_PUNCT] = 0;
  LATCH_TABLE[TABLE_UPPER][TABLE_LOWER] = 28;
  LATCH_TABLE[TABLE_UPPER][TABLE_MIXED] = 29;
  LATCH_TABLE[TABLE_UPPER][TABLE_DIGIT] = 30;
  SHIFT_TABLE[TABLE_UPPER][TABLE_BINARY] = 31;
  SHIFT_TABLE[TABLE_LOWER][TABLE_PUNCT] = 0;
  SHIFT_TABLE[TABLE_LOWER][TABLE_UPPER] = 28;
  LATCH_TABLE[TABLE_LOWER][TABLE_MIXED] = 29;
  LATCH_TABLE[TABLE_LOWER][TABLE_DIGIT] = 30;
  SHIFT_TABLE[TABLE_LOWER][TABLE_BINARY] = 31;
  SHIFT_TABLE[TABLE_MIXED][TABLE_PUNCT] = 0;
  LATCH_TABLE[TABLE_MIXED][TABLE_LOWER] = 28;
  LATCH_TABLE[TABLE_MIXED][TABLE_UPPER] = 29;
  LATCH_TABLE[TABLE_MIXED][TABLE_PUNCT] = 30;
  SHIFT_TABLE[TABLE_MIXED][TABLE_BINARY] = 31;
  LATCH_TABLE[TABLE_PUNCT][TABLE_UPPER] = 31;
  SHIFT_TABLE[TABLE_DIGIT][TABLE_PUNCT] = 0;
  LATCH_TABLE[TABLE_DIGIT][TABLE_UPPER] = 30;
  SHIFT_TABLE[TABLE_DIGIT][TABLE_UPPER] = 31;
  for (NSInteger i = 1; i < NB_BITS_COMPACT_LEN; i++) {
    NB_BITS_COMPACT[i] = (88 + 16 * i) * i;
  }
  for (NSInteger i = 1; i < NB_BITS_LEN; i++) {
    NB_BITS[i] = (112 + 16 * i) * i;
  }
}

/**
 * Encodes the given binary content as an Aztec symbol
 */
+ (ZXAztecCode *)encode:(int8_t *)data len:(NSUInteger)len {
  return [self encode:data len:len minECCPercent:ZX_DEFAULT_AZTEC_EC_PERCENT];
}

/**
 * Encodes the given binary content as an Aztec symbol
 */
+ (ZXAztecCode *)encode:(int8_t *)data len:(NSUInteger)len minECCPercent:(NSInteger)minECCPercent {
  // High-level encode
  ZXBitArray *bits = [self highLevelEncode:data len:len];

  // stuff bits and choose symbol size
  NSInteger eccBits = bits.size * minECCPercent / 100 + 11;
  NSInteger totalSizeBits = bits.size + eccBits;
  NSInteger layers;
  NSInteger wordSize = 0;
  NSInteger totalSymbolBits = 0;
  ZXBitArray *stuffedBits = nil;
  for (layers = 1; layers < NB_BITS_COMPACT_LEN; layers++) {
    if (NB_BITS_COMPACT[layers] >= totalSizeBits) {
      if (wordSize != WORD_SIZE[layers]) {
        wordSize = WORD_SIZE[layers];
        stuffedBits = [self stuffBits:bits wordSize:wordSize];
      }
      totalSymbolBits = NB_BITS_COMPACT[layers];
      if (stuffedBits.size + eccBits <= NB_BITS_COMPACT[layers]) {
        break;
      }
    }
  }
  BOOL compact = YES;
  if (layers == NB_BITS_COMPACT_LEN) {
    compact = false;
    for (layers = 1; layers < NB_BITS_LEN; layers++) {
      if (NB_BITS[layers] >= totalSizeBits) {
        if (wordSize != WORD_SIZE[layers]) {
          wordSize = WORD_SIZE[layers];
          stuffedBits = [self stuffBits:bits wordSize:wordSize];
        }
        totalSymbolBits = NB_BITS[layers];
        if (stuffedBits.size + eccBits <= NB_BITS[layers]) {
          break;
        }
      }
    }
  }
  if (layers == NB_BITS_LEN) {
    [NSException raise:NSInvalidArgumentException format:@"Data too large for an Aztec code"];
  }

  // pad the end
  NSInteger messageSizeInWords = (stuffedBits.size + wordSize - 1) / wordSize;
  for (NSInteger i = messageSizeInWords * wordSize - stuffedBits.size; i > 0; i--) {
    [stuffedBits appendBit:YES];
  }

  // generate check words
  ZXReedSolomonEncoder *rs = [[ZXReedSolomonEncoder alloc] initWithField:[self getGF:wordSize]];
  NSInteger totalSizeInFullWords = totalSymbolBits / wordSize;

  NSInteger messageWords[totalSizeInFullWords];
  [self bitsToWords:stuffedBits wordSize:wordSize totalWords:totalSizeInFullWords message:messageWords];
  [rs encode:messageWords toEncodeLen:totalSizeInFullWords ecBytes:totalSizeInFullWords - messageSizeInWords];

  // convert to bit array and pad in the beginning
  NSInteger startPad = totalSymbolBits % wordSize;
  ZXBitArray *messageBits = [[ZXBitArray alloc] init];
  [messageBits appendBits:0 numBits:startPad];
  for (NSInteger i = 0; i < totalSizeInFullWords; i++) {
    [messageBits appendBits:messageWords[i] numBits:wordSize];
  }

  // generate mode message
  ZXBitArray *modeMessage = [self generateModeMessageCompact:compact layers:layers messageSizeInWords:messageSizeInWords];

  // allocate symbol
  NSInteger baseMatrixSize = compact ? 11 + layers * 4 : 14 + layers * 4; // not including alignment lines
  NSInteger alignmentMap[baseMatrixSize];
  NSInteger matrixSize;
  if (compact) {
    // no alignment marks in compact mode, alignmentMap is a no-op
    matrixSize = baseMatrixSize;
    for (NSInteger i = 0; i < baseMatrixSize; i++) {
      alignmentMap[i] = i;
    }
  } else {
    matrixSize = baseMatrixSize + 1 + 2 * ((baseMatrixSize / 2 - 1) / 15);
    NSInteger origCenter = baseMatrixSize / 2;
    NSInteger center = matrixSize / 2;
    for (NSInteger i = 0; i < origCenter; i++) {
      NSInteger newOffset = i + i / 15;
      alignmentMap[origCenter - i - 1] = center - newOffset - 1;
      alignmentMap[origCenter + i] = center + newOffset + 1;
    }
  }
  ZXBitMatrix *matrix = [[ZXBitMatrix alloc] initWithDimension:matrixSize];

  // draw mode and data bits
  for (NSInteger i = 0, rowOffset = 0; i < layers; i++) {
    NSInteger rowSize = compact ? (layers - i) * 4 + 9 : (layers - i) * 4 + 12;
    for (NSInteger j = 0; j < rowSize; j++) {
      NSInteger columnOffset = j * 2;
      for (NSInteger k = 0; k < 2; k++) {
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
  [self drawModeMessage:matrix compact:compact matrixSize:matrixSize modeMessage:modeMessage];

  // draw alignment marks
  if (compact) {
    [self drawBullsEye:matrix center:matrixSize / 2 size:5];
  } else {
    [self drawBullsEye:matrix center:matrixSize / 2 size:7];
    for (NSInteger i = 0, j = 0; i < baseMatrixSize / 2 - 1; i += 15, j += 16) {
      for (NSInteger k = (matrixSize / 2) & 1; k < matrixSize; k += 2) {
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

+ (void)drawBullsEye:(ZXBitMatrix *)matrix center:(NSInteger)center size:(NSInteger)size {
  for (NSInteger i = 0; i < size; i += 2) {
    for (NSInteger j = center - i; j <= center + i; j++) {
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

+ (ZXBitArray *)generateModeMessageCompact:(BOOL)compact layers:(NSInteger)layers messageSizeInWords:(NSInteger)messageSizeInWords {
  ZXBitArray *modeMessage = [[ZXBitArray alloc] init];
  if (compact) {
    [modeMessage appendBits:layers - 1 numBits:2];
    [modeMessage appendBits:messageSizeInWords - 1 numBits:6];
    modeMessage = [self generateCheckWords:modeMessage totalSymbolBits:28 wordSize:4];
  } else {
    [modeMessage appendBits:layers - 1 numBits:5];
    [modeMessage appendBits:messageSizeInWords - 1 numBits:11];
    modeMessage = [self generateCheckWords:modeMessage totalSymbolBits:40 wordSize:4];
  }
  return modeMessage;
}

+ (void)drawModeMessage:(ZXBitMatrix *)matrix compact:(BOOL)compact matrixSize:(NSInteger)matrixSize modeMessage:(ZXBitArray *)modeMessage {
  if (compact) {
    for (NSInteger i = 0; i < 7; i++) {
      if ([modeMessage get:i]) {
        [matrix setX:matrixSize / 2 - 3 + i y:matrixSize / 2 - 5];
      }
      if ([modeMessage get:i + 7]) {
        [matrix setX:matrixSize / 2 + 5 y:matrixSize / 2 - 3 + i];
      }
      if ([modeMessage get:20 - i]) {
        [matrix setX:matrixSize / 2 - 3 + i y:matrixSize / 2 + 5];
      }
      if ([modeMessage get:27 - i]) {
        [matrix setX:matrixSize / 2 - 5 y:matrixSize / 2 - 3 + i];
      }
    }
  } else {
    for (NSInteger i = 0; i < 10; i++) {
      if ([modeMessage get:i]) {
        [matrix setX:matrixSize / 2 - 5 + i + i / 5 y:matrixSize / 2 - 7];
      }
      if ([modeMessage get:i + 10]) {
        [matrix setX:matrixSize / 2 + 7 y:matrixSize / 2 - 5 + i + i / 5];
      }
      if ([modeMessage get:29 - i]) {
        [matrix setX:matrixSize / 2 - 5 + i + i / 5 y:matrixSize / 2 + 7];
      }
      if ([modeMessage get:39 - i]) {
        [matrix setX:matrixSize / 2 - 7 y:matrixSize / 2 - 5 + i + i / 5];
      }
    }
  }
}

+ (ZXBitArray *)generateCheckWords:(ZXBitArray *)stuffedBits totalSymbolBits:(NSInteger)totalSymbolBits wordSize:(NSInteger)wordSize {
  NSInteger messageSizeInWords = (stuffedBits.size + wordSize - 1) / wordSize;
  for (NSInteger i = messageSizeInWords * wordSize - stuffedBits.size; i > 0; i--) {
    [stuffedBits appendBit:YES];
  }
  ZXReedSolomonEncoder *rs = [[ZXReedSolomonEncoder alloc] initWithField:[self getGF:wordSize]];
  NSInteger totalSizeInFullWords = totalSymbolBits / wordSize;

  NSInteger messageWords[totalSizeInFullWords];
  [self bitsToWords:stuffedBits wordSize:wordSize totalWords:totalSizeInFullWords message:messageWords];

  [rs encode:messageWords toEncodeLen:totalSizeInFullWords ecBytes:totalSizeInFullWords - messageSizeInWords];
  NSInteger startPad = totalSymbolBits % wordSize;
  ZXBitArray *messageBits = [[ZXBitArray alloc] init];
  [messageBits appendBits:0 numBits:startPad];
  for (NSInteger i = 0; i < totalSizeInFullWords; i++) {
    [messageBits appendBits:messageWords[i] numBits:wordSize];
  }
  return messageBits;
}

+ (void)bitsToWords:(ZXBitArray *)stuffedBits wordSize:(NSInteger)wordSize totalWords:(NSInteger)totalWords message:(NSInteger *)message {
  NSInteger i;
  NSInteger n;
  for (i = 0, n = stuffedBits.size / wordSize; i < n; i++) {
    NSInteger value = 0;
    for (NSInteger j = 0; j < wordSize; j++) {
      value |= [stuffedBits get:i * wordSize + j] ? (1 << (wordSize - j - 1)) : 0;
    }
    message[i] = value;
  }
}

+ (ZXGenericGF *)getGF:(NSInteger)wordSize {
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

+ (ZXBitArray *)stuffBits:(ZXBitArray *)bits wordSize:(NSInteger)wordSize {
  ZXBitArray *arrayOut = [[ZXBitArray alloc] init];

  // 1. stuff the bits
  NSInteger n = bits.size;
  NSInteger mask = (1 << wordSize) - 2;
  for (NSInteger i = 0; i < n; i += wordSize) {
    NSInteger word = 0;
    for (NSInteger j = 0; j < wordSize; j++) {
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

  // 2. pad last word to wordSize
  n = arrayOut.size;
  NSInteger remainder = n % wordSize;
  if (remainder != 0) {
    NSInteger j = 1;
    for (NSInteger i = 0; i < remainder; i++) {
      if (![arrayOut get:n - 1 - i]) {
        j = 0;
      }
    }
    for (NSInteger i = remainder; i < wordSize - 1; i++) {
      [arrayOut appendBit:YES];
    }
    [arrayOut appendBit:j == 0];
  }
  return arrayOut;
}

+ (ZXBitArray *)highLevelEncode:(int8_t *)data len:(NSUInteger)len {
  ZXBitArray *bits = [[ZXBitArray alloc] init];
  NSInteger mode = TABLE_UPPER;
  NSInteger idx[5] = {0, 0, 0, 0, 0};
  NSInteger idxnext[5] = {0, 0, 0, 0, 0};

  for (NSInteger i = 0; i < len; i++) {
    NSInteger c = data[i] & 0xFF;
    NSInteger next = i < len - 1 ? data[i + 1] & 0xFF : 0;
    NSInteger punctWord = 0;
    // special case: double-character codes
    if (c == '\r' && next == '\n') {
      punctWord = 2;
    } else if (c == '.' && next == ' ') {
      punctWord = 3;
    } else if (c == ',' && next == ' ') {
      punctWord = 4;
    } else if (c == ':' && next == ' ') {
      punctWord = 5;
    }
    if (punctWord > 0) {
      if (mode == TABLE_PUNCT) {
        [self outputWord:bits mode:TABLE_PUNCT value:punctWord];
        i++;
        continue;
      } else if (SHIFT_TABLE[mode][TABLE_PUNCT] >= 0) {
        [self outputWord:bits mode:mode value:SHIFT_TABLE[mode][TABLE_PUNCT]];
        [self outputWord:bits mode:TABLE_PUNCT value:punctWord];
        i++;
        continue;
      } else if (LATCH_TABLE[mode][TABLE_PUNCT] >= 0) {
        [self outputWord:bits mode:mode value:LATCH_TABLE[mode][TABLE_PUNCT]];
        [self outputWord:bits mode:TABLE_PUNCT value:punctWord];
        mode = TABLE_PUNCT;
        i++;
        continue;
      }
    }
    // find the best matching table, taking current mode and next character into account
    NSInteger firstMatch = -1;
    NSInteger shiftMode = -1;
    NSInteger latchMode = -1;
    NSInteger j;
    for (j = 0; j < TABLE_BINARY; j++) {
      idx[j] = CHAR_MAP[j][c];
      if (idx[j] > 0 && firstMatch < 0) {
        firstMatch = j;
      }
      if (shiftMode < 0 && idx[j] > 0 && SHIFT_TABLE[mode][j] >= 0) {
        shiftMode = j;
      }
      idxnext[j] = CHAR_MAP[j][next];
      if (latchMode < 0 && idx[j] > 0 && (next == 0 || idxnext[j] > 0) && LATCH_TABLE[mode][j] >= 0) {
        latchMode = j;
      }
    }
    if (shiftMode < 0 && latchMode < 0) {
      for (j = 0; j < TABLE_BINARY; j++) {
        if (idx[j] > 0 && LATCH_TABLE[mode][j] >= 0) {
          latchMode = j;
          break;
        }
      }
    }
    if (idx[mode] > 0) {
      // found character in current table - stay in current table
      [self outputWord:bits mode:mode value:idx[mode]];
    } else {
      if (latchMode >= 0) {
        // latch into mode latchMode
        [self outputWord:bits mode:mode value:LATCH_TABLE[mode][latchMode]];
        [self outputWord:bits mode:latchMode value:idx[latchMode]];
        mode = latchMode;
      } else if (shiftMode >= 0) {
        // shift into shiftMode
        [self outputWord:bits mode:mode value:SHIFT_TABLE[mode][shiftMode]];
        [self outputWord:bits mode:shiftMode value:idx[shiftMode]];
      } else {
        if (firstMatch >= 0) {
          // can't switch into this mode from current mode - switch in two steps
          if (mode == TABLE_PUNCT) {
            [self outputWord:bits mode:TABLE_PUNCT value:LATCH_TABLE[TABLE_PUNCT][TABLE_UPPER]];
            mode = TABLE_UPPER;
            i--;
            continue;
          } else if (mode == TABLE_DIGIT) {
            [self outputWord:bits mode:TABLE_DIGIT value:LATCH_TABLE[TABLE_DIGIT][TABLE_UPPER]];
            mode = TABLE_UPPER;
            i--;
            continue;
          }
        }
        // use binary table
        // find the binary string length
        NSInteger k;
        NSInteger lookahead;
        for (k = i + 1, lookahead = 0; k < len; k++) {
          next = data[k] & 0xFF;
          BOOL binary = YES;
          for (j = 0; j < TABLE_BINARY; j++) {
            if (CHAR_MAP[j][next] > 0) {
              binary = NO;
              break;
            }
          }
          if (binary) {
            lookahead = 0;
          } else {
            // skip over single character in between binary bytes
            if (lookahead >= 1) {
              k -= lookahead;
              break;
            }
            lookahead++;
          }
        }
        k -= i;
        // switch into binary table
        switch (mode) {
          case TABLE_UPPER:
          case TABLE_LOWER:
          case TABLE_MIXED:
            [self outputWord:bits mode:mode value:SHIFT_TABLE[mode][TABLE_BINARY]];
            break;
          case TABLE_DIGIT:
            [self outputWord:bits mode:mode value:LATCH_TABLE[mode][TABLE_UPPER]];
            mode = TABLE_UPPER;
            [self outputWord:bits mode:mode value:SHIFT_TABLE[mode][TABLE_BINARY]];
            break;
          case TABLE_PUNCT:
            [self outputWord:bits mode:mode value:LATCH_TABLE[mode][TABLE_UPPER]];
            mode = TABLE_UPPER;
            [self outputWord:bits mode:mode value:SHIFT_TABLE[mode][TABLE_BINARY]];
            break;
        }
        if (k >= 32 && k < 63) { // optimization: split one long form into two short forms, saves 1 bit
          k = 31;
        }
        if (k > 542) { // maximum encodable binary length in long form is 511 + 31
          k = 542;
        }
        if (k < 32) {
          [bits appendBits:k numBits:5];
        } else {
          [bits appendBits:k - 31 numBits:16];
        }
        for (; k > 0; k--, i++) {
          [bits appendBits:data[i] numBits:8];
        }
        i--;
      }
    }
  }
  return bits;

}

+ (void)outputWord:(ZXBitArray *)bits mode:(NSInteger)mode value:(NSInteger)value {
  if (mode == TABLE_DIGIT) {
    [bits appendBits:value numBits:4];
  } else if (mode < TABLE_BINARY) {
    [bits appendBits:value numBits:5];
  } else {
    [bits appendBits:value numBits:8];
  }
}

@end
