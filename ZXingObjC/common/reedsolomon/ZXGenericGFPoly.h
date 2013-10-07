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

/**
 * Represents a polynomial whose coefficients are elements of a GF.
 * Instances of this class are immutable.
 * 
 * Much credit is due to William Rucklidge since portions of this code are an indirect
 * port of his C++ Reed-Solomon implementation.
 */

@class ZXGenericGF;

@interface ZXGenericGFPoly : NSObject

@property (nonatomic, assign, readonly) NSInteger *coefficients;
@property (nonatomic, assign, readonly) NSInteger coefficientsLen;

- (id)initWithField:(ZXGenericGF *)field coefficients:(NSInteger *)coefficients coefficientsLen:(NSInteger)coefficientsLen;
- (NSInteger)degree;
- (BOOL)zero;
- (NSInteger)coefficient:(NSInteger)degree;
- (NSInteger)evaluateAt:(NSInteger)a;
- (ZXGenericGFPoly *)addOrSubtract:(ZXGenericGFPoly *)other;
- (ZXGenericGFPoly *)multiply:(ZXGenericGFPoly *)other;
- (ZXGenericGFPoly *)multiplyScalar:(NSInteger)scalar;
- (ZXGenericGFPoly *)multiplyByMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient;
- (NSArray *)divide:(ZXGenericGFPoly *)other;

@end
