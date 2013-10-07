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

#import "ZXMathUtils.h"

@implementation ZXMathUtils

+ (NSInteger)round:(float)d {
  return (NSInteger)(d + 0.5f);
}

+ (float)distance:(float)aX aY:(float)aY bX:(float)bX bY:(float)bY {
  float xDiff = aX - bX;
  float yDiff = aY - bY;
  return sqrtf(xDiff * xDiff + yDiff * yDiff);
}

+ (float)distanceInt:(NSInteger)aX aY:(NSInteger)aY bX:(NSInteger)bX bY:(NSInteger)bY {
  NSInteger xDiff = aX - bX;
  NSInteger yDiff = aY - bY;
  return sqrtf(xDiff * xDiff + yDiff * yDiff);
}

@end
