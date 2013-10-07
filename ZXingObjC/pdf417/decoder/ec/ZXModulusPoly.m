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

#import "ZXModulusGF.h"
#import "ZXModulusPoly.h"

@interface ZXModulusPoly ()

@property (nonatomic, assign) NSInteger *coefficients;
@property (nonatomic, assign) NSInteger coefficientsLen;
@property (nonatomic, weak) ZXModulusGF *field;

@end

@implementation ZXModulusPoly

- (id)initWithField:(ZXModulusGF *)field coefficients:(NSInteger *)coefficients coefficientsLen:(NSInteger)coefficientsLen {
  if (self = [super init]) {
    _field = field;
    if (coefficientsLen > 1 && coefficients[0] == 0) {
      // Leading term must be non-zero for anything except the constant polynomial "0"
      NSInteger firstNonZero = 1;
      while (firstNonZero < coefficientsLen && coefficients[firstNonZero] == 0) {
        firstNonZero++;
      }
      if (firstNonZero == coefficientsLen) {
        ZXModulusPoly *zero = field.zero;
        _coefficients = (NSInteger *)malloc(zero.coefficientsLen * sizeof(NSInteger));
        memcpy(_coefficients, zero.coefficients, zero.coefficientsLen * sizeof(NSInteger));
      } else {
        _coefficientsLen = (coefficientsLen - firstNonZero);
        _coefficients = (NSInteger *)malloc(_coefficientsLen * sizeof(NSInteger));
        for (NSInteger i = 0; i < _coefficientsLen; i++) {
          _coefficients[i] = coefficients[firstNonZero + i];
        }
      }
    } else {
      _coefficients = (NSInteger *)malloc(coefficientsLen * sizeof(NSInteger));
      memcpy(_coefficients, coefficients, coefficientsLen * sizeof(NSInteger));
      _coefficientsLen = coefficientsLen;
    }
  }

  return self;
}

- (void)dealloc {
  if (_coefficients != NULL) {
    free(_coefficients);
    _coefficients = NULL;
  }
}

- (NSInteger)degree {
  return self.coefficientsLen - 1;
}

- (BOOL)zero {
  return self.coefficients[0] == 0;
}

- (NSInteger)coefficient:(NSInteger)degree {
  return self.coefficients[self.coefficientsLen - 1 - degree];
}

- (NSInteger)evaluateAt:(NSInteger)a {
  if (a == 0) {
    return [self coefficient:0];
  }
  NSInteger size = self.coefficientsLen;
  if (a == 1) {
    // Just the sum of the coefficients
    NSInteger result = 0;
    for (NSInteger i = 0; i < size; i++) {
      result = [self.field add:result b:self.coefficients[i]];
    }
    return result;
  }
  NSInteger result = self.coefficients[0];
  for (NSInteger i = 1; i < size; i++) {
    result = [self.field add:[self.field multiply:a b:result] b:self.coefficients[i]];
  }
  return result;
}

- (ZXModulusPoly *)add:(ZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXModulusPolys do not have same ZXModulusGF field"];
  }
  if (self.zero) {
    return other;
  }
  if (other.zero) {
    return self;
  }

  NSInteger *smallerCoefficients = self.coefficients;
  NSInteger smallerCoefficientsLen = self.coefficientsLen;
  NSInteger *largerCoefficients = other.coefficients;
  NSInteger largerCoefficientsLen = other.coefficientsLen;
  if (smallerCoefficientsLen > largerCoefficientsLen) {
    NSInteger *temp = smallerCoefficients;
    NSInteger tempLen = smallerCoefficientsLen;
    smallerCoefficients = largerCoefficients;
    smallerCoefficientsLen = largerCoefficientsLen;
    largerCoefficients = temp;
    largerCoefficientsLen = tempLen;
  }
  NSInteger sumDiff[largerCoefficientsLen];
  NSInteger lengthDiff = largerCoefficientsLen - smallerCoefficientsLen;
  for (NSInteger i = 0; i < lengthDiff; i++) {
    sumDiff[i] = largerCoefficients[i];
  }
  for (NSInteger i = lengthDiff; i < largerCoefficientsLen; i++) {
    sumDiff[i] = [self.field add:smallerCoefficients[i - lengthDiff] b:largerCoefficients[i]];
  }

  return [[ZXModulusPoly alloc] initWithField:self.field coefficients:sumDiff coefficientsLen:largerCoefficientsLen];
}

- (ZXModulusPoly *)subtract:(ZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXModulusPolys do not have same ZXModulusGF field"];
  }
  if (self.zero) {
    return self;
  }
  return [self add:[other negative]];
}

- (ZXModulusPoly *)multiply:(ZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXModulusPolys do not have same ZXModulusGF field"];
  }
  if (self.zero || other.zero) {
    return self.field.zero;
  }
  NSInteger *aCoefficients = self.coefficients;
  NSInteger aLength = self.coefficientsLen;
  NSInteger *bCoefficients = other.coefficients;
  NSInteger bLength = other.coefficientsLen;
  NSInteger productLen = aLength + bLength - 1;
  NSInteger product[productLen];
  memset(product, 0, productLen * sizeof(NSInteger));

  for (NSInteger i = 0; i < aLength; i++) {
    NSInteger aCoeff = aCoefficients[i];
    for (NSInteger j = 0; j < bLength; j++) {
      product[i + j] = [self.field add:product[i + j]
                                     b:[self.field multiply:aCoeff b:bCoefficients[j]]];
    }
  }
  return [[ZXModulusPoly alloc] initWithField:self.field coefficients:product coefficientsLen:productLen];
}

- (ZXModulusPoly *)negative {
  NSInteger negativeCoefficientsLen = self.coefficientsLen;
  NSInteger negativeCoefficients[negativeCoefficientsLen];
  for (NSInteger i = 0; i < self.coefficientsLen; i++) {
    negativeCoefficients[i] = [self.field subtract:0 b:self.coefficients[i]];
  }
  return [[ZXModulusPoly alloc] initWithField:self.field coefficients:negativeCoefficients coefficientsLen:negativeCoefficientsLen];
}

- (ZXModulusPoly *)multiplyScalar:(NSInteger)scalar {
  if (scalar == 0) {
    return self.field.zero;
  }
  if (scalar == 1) {
    return self;
  }
  NSInteger size = self.coefficientsLen;
  NSInteger product[size];
  for (NSInteger i = 0; i < size; i++) {
    product[i] = [self.field multiply:self.coefficients[i] b:scalar];
  }
  return [[ZXModulusPoly alloc] initWithField:self.field coefficients:product coefficientsLen:size];
}

- (ZXModulusPoly *)multiplyByMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient {
  if (degree < 0) {
    [NSException raise:NSInvalidArgumentException format:@"Degree must be greater than 0."];
  }
  if (coefficient == 0) {
    return self.field.zero;
  }
  NSInteger size = self.coefficientsLen;
  NSInteger product[size + degree];
  for (NSInteger i = 0; i < size + degree; i++) {
    if (i < size) {
      product[i] = [self.field multiply:self.coefficients[i] b:coefficient];
    } else {
      product[i] = 0;
    }
  }

  return [[ZXModulusPoly alloc] initWithField:self.field coefficients:product coefficientsLen:size + degree];
}

- (NSArray *)divide:(ZXModulusPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXModulusPolys do not have same ZXModulusGF field"];
  }
  if (other.zero) {
    [NSException raise:NSInvalidArgumentException format:@"Divide by 0"];
  }

  ZXModulusPoly *quotient = self.field.zero;
  ZXModulusPoly *remainder = self;

  NSInteger denominatorLeadingTerm = [other coefficient:other.degree];
  NSInteger inverseDenominatorLeadingTerm = [self.field inverse:denominatorLeadingTerm];

  while ([remainder degree] >= other.degree && !remainder.zero) {
    NSInteger degreeDifference = remainder.degree - other.degree;
    NSInteger scale = [self.field multiply:[remainder coefficient:remainder.degree] b:inverseDenominatorLeadingTerm];
    ZXModulusPoly *term = [other multiplyByMonomial:degreeDifference coefficient:scale];
    ZXModulusPoly *iterationQuotient = [self.field buildMonomial:degreeDifference coefficient:scale];
    quotient = [quotient add:iterationQuotient];
    remainder = [remainder subtract:term];
  }

  return @[quotient, remainder];
}

- (NSString *)description {
  NSMutableString *result = [NSMutableString stringWithCapacity:8 * [self degree]];
  for (NSInteger degree = [self degree]; degree >= 0; degree--) {
    NSInteger coefficient = [self coefficient:degree];
    if (coefficient != 0) {
      if (coefficient < 0) {
        [result appendString:@" - "];
        coefficient = -coefficient;
      } else {
        if ([result length] > 0) {
          [result appendString:@" + "];
        }
      }
      if (degree == 0 || coefficient != 1) {
        [result appendFormat:@"%ld", (long)coefficient];
      }
      if (degree != 0) {
        if (degree == 1) {
          [result appendString:@"x"];
        } else {
          [result appendString:@"x^"];
          [result appendFormat:@"%ld", (long)degree];
        }
      }
    }
  }

  return result;
}

@end
