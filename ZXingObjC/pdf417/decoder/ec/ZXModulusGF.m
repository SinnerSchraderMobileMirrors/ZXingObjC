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
#import "ZXPDF417Common.h"

@interface ZXModulusGF ()

@property (nonatomic, strong) NSMutableArray *expTable;
@property (nonatomic, strong) NSMutableArray *logTable;
@property (nonatomic, assign) NSInteger modulus;

@end

@implementation ZXModulusGF

+ (ZXModulusGF *)PDF417_GF {
  return [[ZXModulusGF alloc] initWithModulus:ZXPDF417_NUMBER_OF_CODEWORDS generator:3];
}

- (id)initWithModulus:(NSInteger)modulus generator:(NSInteger)generator {
  if (self = [super init]) {
    _modulus = modulus;
    _expTable = [NSMutableArray arrayWithCapacity:self.modulus];
    _logTable = [NSMutableArray arrayWithCapacity:self.modulus];
    NSInteger x = 1;
    for (NSInteger i = 0; i < modulus; i++) {
      [_expTable addObject:@(x)];
      x = (x * generator) % modulus;
    }

    for (NSInteger i = 0; i < self.size; i++) {
      [_logTable addObject:@0];
    }

    for (NSInteger i = 0; i < self.size - 1; i++) {
      _logTable[[_expTable[i] intValue]] = @(i);
    }
    // logTable[0] == 0 but this should never be used
    NSInteger zeroInt = 0;
    _zero = [[ZXModulusPoly alloc] initWithField:self coefficients:&zeroInt coefficientsLen:1];

    NSInteger oneInt = 1;
    _one = [[ZXModulusPoly alloc] initWithField:self coefficients:&oneInt coefficientsLen:1];
  }

  return self;
}

- (ZXModulusPoly *)buildMonomial:(NSInteger)degree coefficient:(NSInteger)coefficient {
  if (degree < 0) {
    [NSException raise:NSInvalidArgumentException format:@"Degree must be greater than 0."];
  }
  if (coefficient == 0) {
    return self.zero;
  }

  NSInteger coefficientsLen = degree + 1;
  NSInteger coefficients[coefficientsLen];
  coefficients[0] = coefficient;
  for (NSInteger i = 1; i < coefficientsLen; i++) {
    coefficients[i] = 0;
  }
  return [[ZXModulusPoly alloc] initWithField:self coefficients:coefficients coefficientsLen:coefficientsLen];
}

- (NSInteger)add:(NSInteger)a b:(NSInteger)b {
  return (a + b) % self.modulus;
}

- (NSInteger)subtract:(NSInteger)a b:(NSInteger)b {
  return (self.modulus + a - b) % self.modulus;
}

- (NSInteger)exp:(NSInteger)a {
  return [self.expTable[a] intValue];
}

- (NSInteger)log:(NSInteger)a {
  if (a == 0) {
    [NSException raise:NSInvalidArgumentException format:@"Argument must be non-zero."];
  }
  return [self.logTable[a] intValue];
}

- (NSInteger)inverse:(NSInteger)a {
  if (a == 0) {
    [NSException raise:NSInvalidArgumentException format:@"Argument must be non-zero."];
  }
  return [self.expTable[self.size - [self.logTable[a] intValue] - 1] intValue];
}

- (NSInteger)multiply:(NSInteger)a b:(NSInteger)b {
  if (a == 0 || b == 0) {
    return 0;
  }

  NSInteger logSum = [self.logTable[a] intValue] + [self.logTable[b] intValue];
  return [self.expTable[logSum % (self.modulus - 1)] intValue];
}

- (NSInteger)size {
  return self.modulus;
}

@end
