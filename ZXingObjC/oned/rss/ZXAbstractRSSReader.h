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

#import "ZXOneDReader.h"

typedef enum {
	RSS_PATTERNS_RSS14_PATTERNS = 0,
	RSS_PATTERNS_RSS_EXPANDED_PATTERNS
} RSS_PATTERNS;

@interface ZXAbstractRSSReader : ZXOneDReader

@property (nonatomic, assign, readonly) NSInteger *decodeFinderCounters;
@property (nonatomic, assign, readonly) NSUInteger decodeFinderCountersLen;
@property (nonatomic, assign, readonly) NSInteger *dataCharacterCounters;
@property (nonatomic, assign, readonly) NSUInteger dataCharacterCountersLen;
@property (nonatomic, assign, readonly) float *oddRoundingErrors;
@property (nonatomic, assign, readonly) NSUInteger oddRoundingErrorsLen;
@property (nonatomic, assign, readonly) float *evenRoundingErrors;
@property (nonatomic, assign, readonly) NSUInteger evenRoundingErrorsLen;
@property (nonatomic, assign, readonly) NSInteger *oddCounts;
@property (nonatomic, assign, readonly) NSUInteger oddCountsLen;
@property (nonatomic, assign, readonly) NSInteger *evenCounts;
@property (nonatomic, assign, readonly) NSUInteger evenCountsLen;

+ (NSInteger)parseFinderValue:(NSInteger *)counters countersSize:(NSUInteger)countersSize finderPatternType:(RSS_PATTERNS)finderPatternType;
+ (NSInteger)count:(NSInteger *)array arrayLen:(NSUInteger)arrayLen;
+ (void)increment:(NSInteger *)array arrayLen:(NSUInteger)arrayLen errors:(float *)errors;
+ (void)decrement:(NSInteger *)array arrayLen:(NSUInteger)arrayLen errors:(float *)errors;
+ (BOOL)isFinderPattern:(NSInteger *)counters countersLen:(NSUInteger)countersLen;

@end
