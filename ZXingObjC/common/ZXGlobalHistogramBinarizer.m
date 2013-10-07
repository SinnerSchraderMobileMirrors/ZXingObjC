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

#import "ZXGlobalHistogramBinarizer.h"
#import "ZXBitArray.h"
#import "ZXBitMatrix.h"
#import "ZXErrors.h"
#import "ZXLuminanceSource.h"

NSInteger const LUMINANCE_BITS = 5;
NSInteger const LUMINANCE_SHIFT = 8 - LUMINANCE_BITS;
NSInteger const LUMINANCE_BUCKETS = 1 << LUMINANCE_BITS;

@interface ZXGlobalHistogramBinarizer ()

@property (nonatomic, assign) int8_t *luminances;
@property (nonatomic, assign) NSInteger luminancesCount;
@property (nonatomic, assign) NSInteger *buckets;

@end

@implementation ZXGlobalHistogramBinarizer

- (id)initWithSource:(ZXLuminanceSource *)source {
  if (self = [super initWithSource:source]) {
    _luminances = NULL;
    _luminancesCount = 0;
    _buckets = (NSInteger *)malloc(LUMINANCE_BUCKETS * sizeof(NSInteger));
  }

  return self;
}

- (void)dealloc {
  if (_luminances != NULL) {
    free(_luminances);
    _luminances = NULL;
  }

  if (_buckets != NULL) {
    free(_buckets);
    _buckets = NULL;
  }
}

- (ZXBitArray *)blackRow:(NSInteger)y row:(ZXBitArray *)row error:(NSError **)error {
  ZXLuminanceSource *source = self.luminanceSource;
  NSInteger width = source.width;
  if (row == nil || row.size < width) {
    row = [[ZXBitArray alloc] initWithSize:width];
  } else {
    [row clear];
  }

  [self initArrays:width];
  int8_t *localLuminances = [source row:y];
  NSInteger *localBuckets = (NSInteger *)malloc(LUMINANCE_BUCKETS * sizeof(NSInteger));
  memset(localBuckets, 0, LUMINANCE_BUCKETS * sizeof(NSInteger));
  for (NSInteger x = 0; x < width; x++) {
    NSInteger pixel = localLuminances[x] & 0xff;
    localBuckets[pixel >> LUMINANCE_SHIFT]++;
  }
  NSInteger blackPoint = [self estimateBlackPoint:localBuckets];
  free(localBuckets);
  localBuckets = NULL;
  if (blackPoint == -1) {
    free(localLuminances);
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }

  NSInteger left = localLuminances[0] & 0xff;
  NSInteger center = localLuminances[1] & 0xff;
  for (NSInteger x = 1; x < width - 1; x++) {
    NSInteger right = localLuminances[x + 1] & 0xff;
    NSInteger luminance = ((center << 2) - left - right) >> 1;
    if (luminance < blackPoint) {
      [row set:x];
    }
    left = center;
    center = right;
  }

  free(localLuminances);
  return row;
}

- (ZXBitMatrix *)blackMatrixWithError:(NSError **)error {
  ZXLuminanceSource *source = self.luminanceSource;
  NSInteger width = source.width;
  NSInteger height = source.height;
  ZXBitMatrix *matrix = [[ZXBitMatrix alloc] initWithWidth:width height:height];

  [self initArrays:width];

  NSInteger *localBuckets = (NSInteger *)malloc(LUMINANCE_BUCKETS * sizeof(NSInteger));
  memset(localBuckets, 0, LUMINANCE_BUCKETS * sizeof(NSInteger));
  for (NSInteger y = 1; y < 5; y++) {
    NSInteger row = height * y / 5;
    int8_t *localLuminances = [source row:row];
    NSInteger right = (width << 2) / 5;
    for (NSInteger x = width / 5; x < right; x++) {
      NSInteger pixel = localLuminances[x] & 0xff;
      localBuckets[pixel >> LUMINANCE_SHIFT]++;
    }
  }
  NSInteger blackPoint = [self estimateBlackPoint:localBuckets];
  free(localBuckets);
  localBuckets = NULL;

  if (blackPoint == -1) {
    if (error) *error = NotFoundErrorInstance();
    return nil;
  }

  int8_t *localLuminances = source.matrix;
  for (NSInteger y = 0; y < height; y++) {
    NSInteger offset = y * width;
    for (NSInteger x = 0; x < width; x++) {
      NSInteger pixel = localLuminances[offset + x] & 0xff;
      if (pixel < blackPoint) {
        [matrix setX:x y:y];
      }
    }
  }

  return matrix;
}

- (ZXBinarizer *)createBinarizer:(ZXLuminanceSource *)source {
  return [[ZXGlobalHistogramBinarizer alloc] initWithSource:source];
}

- (void)initArrays:(NSInteger)luminanceSize {
  if (self.luminances == NULL || self.luminancesCount < luminanceSize) {
    if (self.luminances != NULL) {
      free(self.luminances);
    }
    self.luminances = (int8_t *)malloc(luminanceSize * sizeof(int8_t));
    self.luminancesCount = luminanceSize;
  }

  for (NSInteger x = 0; x < LUMINANCE_BUCKETS; x++) {
    self.buckets[x] = 0;
  }
}

- (NSInteger)estimateBlackPoint:(NSInteger *)otherBuckets {
  NSInteger numBuckets = LUMINANCE_BUCKETS;
  NSInteger maxBucketCount = 0;
  NSInteger firstPeak = 0;
  NSInteger firstPeakSize = 0;

  for (NSInteger x = 0; x < numBuckets; x++) {
    if (otherBuckets[x] > firstPeakSize) {
      firstPeak = x;
      firstPeakSize = otherBuckets[x];
    }
    if (otherBuckets[x] > maxBucketCount) {
      maxBucketCount = otherBuckets[x];
    }
  }

  NSInteger secondPeak = 0;
  NSInteger secondPeakScore = 0;
  for (NSInteger x = 0; x < numBuckets; x++) {
    NSInteger distanceToBiggest = x - firstPeak;
    NSInteger score = otherBuckets[x] * distanceToBiggest * distanceToBiggest;
    if (score > secondPeakScore) {
      secondPeak = x;
      secondPeakScore = score;
    }
  }

  if (firstPeak > secondPeak) {
    NSInteger temp = firstPeak;
    firstPeak = secondPeak;
    secondPeak = temp;
  }

  if (secondPeak - firstPeak <= numBuckets >> 4) {
    return -1;
  }

  NSInteger bestValley = secondPeak - 1;
  NSInteger bestValleyScore = -1;
  for (NSInteger x = secondPeak - 1; x > firstPeak; x--) {
    NSInteger fromFirst = x - firstPeak;
    NSInteger score = fromFirst * fromFirst * (secondPeak - x) * (maxBucketCount - otherBuckets[x]);
    if (score > bestValleyScore) {
      bestValley = x;
      bestValleyScore = score;
    }
  }

  return bestValley << LUMINANCE_SHIFT;
}

@end
