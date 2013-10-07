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

@class ZXModulusGF;

@interface ZXModulusPoly : NSObject

- (id)initWithField:(ZXModulusGF *)field coefficients:(NSInteger *)coefficients coefficientsLen:(NSInteger)coefficientsLen;
- (NSInteger)degree;
- (BOOL)zero;
- (NSInteger)coefficient:(NSInteger)degree;
- (NSInteger)evaluateAt:(NSInteger)a;
- (ZXModulusPoly *)add:(ZXModulusPoly *)other;
- (ZXModulusPoly *)subtract:(ZXModulusPoly *)other;
- (ZXModulusPoly *)multiply:(ZXModulusPoly *)other;
- (ZXModulusPoly *)negative;
- (ZXModulusPoly *)multiplyScalar:(NSInteger)scalar;
- (ZXModulusPoly *)multiplyByMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient;
- (NSArray *)divide:(ZXModulusPoly *)other;

@end
