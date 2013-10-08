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

#import "ZXGenericGF.h"
#import "ZXGenericGFPoly.h"

@interface ZXGenericGFPoly ()

@property (nonatomic, strong) ZXGenericGF *field;

@end

@implementation ZXGenericGFPoly

- (id)initWithField:(ZXGenericGF *)field coefficients:(NSInteger *)coefficients coefficientsLen:(NSInteger)coefficientsLen {
  if (self = [super init]) {
    _field = field;
    if (coefficientsLen > 1 && coefficients[0] == 0) {
      NSInteger firstNonZero = 1;
      while (firstNonZero < coefficientsLen && coefficients[firstNonZero] == 0) {
        firstNonZero++;
      }
      if (firstNonZero == coefficientsLen) {
        ZXGenericGFPoly *zero = [field zero];
        _coefficientsLen = zero.coefficientsLen;
        _coefficients = (NSInteger *)malloc(_coefficientsLen * sizeof(NSInteger));
        memcpy(_coefficients, zero.coefficients, _coefficientsLen * sizeof(NSInteger));
      } else {
        _coefficientsLen = (coefficientsLen - firstNonZero);
        _coefficients = (NSInteger *)malloc(_coefficientsLen * sizeof(NSInteger));
        memcpy(_coefficients, coefficients + firstNonZero, _coefficientsLen* sizeof(NSInteger));
      }
    } else {
      _coefficientsLen = coefficientsLen;
      _coefficients = (NSInteger *)malloc(_coefficientsLen * sizeof(NSInteger));
      memcpy(_coefficients, coefficients, _coefficientsLen * sizeof(NSInteger));
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
    NSInteger result = 0;
    for (NSInteger i = 0; i < size; i++) {
      result = [ZXGenericGF addOrSubtract:result b:self.coefficients[i]];
    }
    return result;
  }
  NSInteger result = self.coefficients[0];
  for (NSInteger i = 1; i < size; i++) {
    result = [ZXGenericGF addOrSubtract:[self.field multiply:a b:result] b:self.coefficients[i]];
  }
  return result;
}

- (ZXGenericGFPoly *)addOrSubtract:(ZXGenericGFPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXGenericGFPolys do not have same ZXGenericGF field"];
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
    sumDiff[i] = [ZXGenericGF addOrSubtract:smallerCoefficients[i - lengthDiff] b:largerCoefficients[i]];
  }

  return [[ZXGenericGFPoly alloc] initWithField:self.field coefficients:sumDiff coefficientsLen:largerCoefficientsLen];
}

- (ZXGenericGFPoly *) multiply:(ZXGenericGFPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXGenericGFPolys do not have same GenericGF field"];
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
      product[i + j] = [ZXGenericGF addOrSubtract:product[i + j]
                                                b:[self.field multiply:aCoeff b:bCoefficients[j]]];
    }
  }
  return [[ZXGenericGFPoly alloc] initWithField:self.field coefficients:product coefficientsLen:productLen];
}

- (ZXGenericGFPoly *)multiplyScalar:(NSInteger)scalar {
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
  return [[ZXGenericGFPoly alloc] initWithField:self.field coefficients:product coefficientsLen:size];
}

- (ZXGenericGFPoly *)multiplyByMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient {
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

  return [[ZXGenericGFPoly alloc] initWithField:self.field coefficients:product coefficientsLen:size + degree];
}

- (NSArray *)divide:(ZXGenericGFPoly *)other {
  if (![self.field isEqual:other.field]) {
    [NSException raise:NSInvalidArgumentException format:@"ZXGenericGFPolys do not have same ZXGenericGF field"];
  }
  if (other.zero) {
    [NSException raise:NSInvalidArgumentException format:@"Divide by 0"];
  }

  ZXGenericGFPoly *quotient = self.field.zero;
  ZXGenericGFPoly *remainder = self;

  NSInteger denominatorLeadingTerm = [other coefficient:other.degree];
  NSInteger inverseDenominatorLeadingTerm = [self.field inverse:denominatorLeadingTerm];

  while ([remainder degree] >= other.degree && !remainder.zero) {
    NSInteger degreeDifference = remainder.degree - other.degree;
    NSInteger scale = [self.field multiply:[remainder coefficient:remainder.degree] b:inverseDenominatorLeadingTerm];
    ZXGenericGFPoly *term = [other multiplyByMonomial:degreeDifference coefficient:scale];
    ZXGenericGFPoly *iterationQuotient = [self.field buildMonomial:degreeDifference coefficient:scale];
    quotient = [quotient addOrSubtract:iterationQuotient];
    remainder = [remainder addOrSubtract:term];
  }

  return @[quotient, remainder];
}

- (NSString *) description {
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
        NSInteger alphaPower = [self.field log:coefficient];
        if (alphaPower == 0) {
          [result appendString:@"1"];
        } else if (alphaPower == 1) {
          [result appendString:@"a"];
        } else {
          [result appendString:@"a^"];
          [result appendFormat:@"%ld", (long)alphaPower];
        }
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
