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

@class ZXModulusPoly;

@interface ZXModulusGF : NSObject

@property (nonatomic, strong) ZXModulusPoly *one;
@property (nonatomic, strong) ZXModulusPoly *zero;

+ (ZXModulusGF *)PDF417_GF;

- (id)initWithModulus:(NSInteger)modulus generator:(NSInteger)generator;

- (ZXModulusPoly *)buildMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient;
- (NSInteger)add:(NSInteger)a b:(NSInteger)b;
- (NSInteger)subtract:(NSInteger)a b:(NSInteger)b;
- (NSInteger)exp:(NSInteger)a;
- (NSInteger)log:(NSInteger)a;
- (NSInteger)inverse:(NSInteger)a;
- (NSInteger)multiply:(NSInteger)a b:(NSInteger)b;
- (NSInteger)size;

@end
