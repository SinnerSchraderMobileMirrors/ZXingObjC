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

#import "ZXAbstractRSSReader.h"

static NSInteger MAX_AVG_VARIANCE;
static NSInteger MAX_INDIVIDUAL_VARIANCE;

float const MIN_FINDER_PATTERN_RATIO = 9.5f / 12.0f;
float const MAX_FINDER_PATTERN_RATIO = 12.5f / 14.0f;

#define RSS14_FINDER_PATTERNS_LEN 9
#define RSS14_FINDER_PATTERNS_SUB_LEN 4
const NSInteger RSS14_FINDER_PATTERNS[RSS14_FINDER_PATTERNS_LEN][RSS14_FINDER_PATTERNS_SUB_LEN] = {
  {3,8,2,1},
  {3,5,5,1},
  {3,3,7,1},
  {3,1,9,1},
  {2,7,4,1},
  {2,5,6,1},
  {2,3,8,1},
  {1,5,7,1},
  {1,3,9,1},
};

#define RSS_EXPANDED_FINDER_PATTERNS_LEN 6
#define RSS_EXPANDED_FINDER_PATTERNS_SUB_LEN 4
const NSInteger RSS_EXPANDED_FINDER_PATTERNS[RSS_EXPANDED_FINDER_PATTERNS_LEN][RSS_EXPANDED_FINDER_PATTERNS_SUB_LEN] = {
  {1,8,4,1}, // A
  {3,6,4,1}, // B
  {3,4,6,1}, // C
  {3,2,8,1}, // D
  {2,6,5,1}, // E
  {2,2,9,1}  // F
};

@implementation ZXAbstractRSSReader

+ (void)initialize {
  MAX_AVG_VARIANCE = (NSInteger)(PATTERN_MATCH_RESULT_SCALE_FACTOR * 0.2f);
  MAX_INDIVIDUAL_VARIANCE = (NSInteger)(PATTERN_MATCH_RESULT_SCALE_FACTOR * 0.45f);
}

- (id)init {
  if (self = [super init]) {
    _decodeFinderCountersLen = 4;
    _decodeFinderCounters = (NSInteger *)malloc(_decodeFinderCountersLen * sizeof(NSInteger));
    memset(self.decodeFinderCounters, 0, self.decodeFinderCountersLen * sizeof(NSInteger));

    _dataCharacterCountersLen = 8;
    _dataCharacterCounters = (NSInteger *)malloc(_dataCharacterCountersLen * sizeof(NSInteger));
    memset(self.dataCharacterCounters, 0, self.dataCharacterCountersLen * sizeof(NSInteger));

    _oddRoundingErrorsLen = 4;
    _oddRoundingErrors = (float *)malloc(_oddRoundingErrorsLen * sizeof(float));
    memset(_oddRoundingErrors, 0, _oddRoundingErrorsLen * sizeof(float));

    _evenRoundingErrorsLen = 4;
    _evenRoundingErrors = (float *)malloc(_evenRoundingErrorsLen * sizeof(float));
    memset(_evenRoundingErrors, 0, _evenRoundingErrorsLen * sizeof(float));

    _oddCountsLen = _dataCharacterCountersLen / 2;
    _oddCounts = (NSInteger *)malloc(_oddCountsLen * sizeof(NSInteger));
    memset(_oddCounts, 0, _oddCountsLen * sizeof(NSInteger));

    _evenCountsLen = _dataCharacterCountersLen / 2;
    _evenCounts = (NSInteger *)malloc(_evenCountsLen * sizeof(NSInteger));
    memset(_evenCounts, 0, _evenCountsLen * sizeof(NSInteger));
  }

  return self;
}

- (void)dealloc {
  if (_decodeFinderCounters != NULL) {
    free(_decodeFinderCounters);
    _decodeFinderCounters = NULL;
  }

  if (_dataCharacterCounters != NULL) {
    free(_dataCharacterCounters);
    _dataCharacterCounters = NULL;
  }

  if (_oddRoundingErrors != NULL) {
    free(_oddRoundingErrors);
    _oddRoundingErrors = NULL;
  }

  if (_evenRoundingErrors != NULL) {
    free(_evenRoundingErrors);
    _evenRoundingErrors = NULL;
  }

  if (_oddCounts != NULL) {
    free(_oddCounts);
    _oddCounts = NULL;
  }

  if (_evenCounts != NULL) {
    free(_evenCounts);
    _evenCounts = NULL;
  }
}

+ (NSInteger)parseFinderValue:(NSInteger *)counters countersSize:(NSUInteger)countersSize finderPatternType:(RSS_PATTERNS)finderPatternType {
  switch (finderPatternType) {
    case RSS_PATTERNS_RSS14_PATTERNS:
      for (NSInteger value = 0; value < RSS14_FINDER_PATTERNS_LEN; value++) {
        if ([self patternMatchVariance:counters countersSize:countersSize pattern:(NSInteger *)RSS14_FINDER_PATTERNS[value] maxIndividualVariance:MAX_INDIVIDUAL_VARIANCE] < MAX_AVG_VARIANCE) {
          return value;
        }
      }
      break;

    case RSS_PATTERNS_RSS_EXPANDED_PATTERNS:
      for (NSInteger value = 0; value < RSS_EXPANDED_FINDER_PATTERNS_LEN; value++) {
        if ([self patternMatchVariance:counters countersSize:countersSize pattern:(NSInteger *)RSS_EXPANDED_FINDER_PATTERNS[value] maxIndividualVariance:MAX_INDIVIDUAL_VARIANCE] < MAX_AVG_VARIANCE) {
          return value;
        }
      }
      break;
      
    default:
      break;
  }

  return -1;
}

+ (NSInteger)count:(NSInteger *)array arrayLen:(NSUInteger)arrayLen {
  NSInteger count = 0;

  for (NSInteger i = 0; i < arrayLen; i++) {
    count += array[i];
  }

  return count;
}

+ (void)increment:(NSInteger *)array arrayLen:(NSUInteger)arrayLen errors:(float *)errors {
  NSInteger index = 0;
  float biggestError = errors[0];
  for (NSInteger i = 1; i < arrayLen; i++) {
    if (errors[i] > biggestError) {
      biggestError = errors[i];
      index = i;
    }
  }
  array[index]++;
}

+ (void)decrement:(NSInteger *)array arrayLen:(NSUInteger)arrayLen errors:(float *)errors {
  NSInteger index = 0;
  float biggestError = errors[0];
  for (NSInteger i = 1; i < arrayLen; i++) {
    if (errors[i] < biggestError) {
      biggestError = errors[i];
      index = i;
    }
  }
  array[index]--;
}

+ (BOOL)isFinderPattern:(NSInteger *)counters countersLen:(NSUInteger)countersLen {
  NSInteger firstTwoSum = counters[0] + counters[1];
  NSInteger sum = firstTwoSum + counters[2] + counters[3];
  float ratio = (float)firstTwoSum / (float)sum;
  if (ratio >= MIN_FINDER_PATTERN_RATIO && ratio <= MAX_FINDER_PATTERN_RATIO) {
    NSInteger minCounter = INT_MAX;
    NSInteger maxCounter = INT_MIN;
    for (NSInteger i = 0; i < countersLen; i++) {
      NSInteger counter = counters[i];
      if (counter > maxCounter) {
        maxCounter = counter;
      }
      if (counter < minCounter) {
        minCounter = counter;
      }
    }

    return maxCounter < 10 * minCounter;
  }
  return NO;
}

@end
