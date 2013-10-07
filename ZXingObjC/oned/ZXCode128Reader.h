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

/**
 * Decodes Code 128 barcodes.
 */

extern const NSInteger CODE_PATTERNS[][7];

extern const NSInteger CODE_START_B;
extern const NSInteger CODE_START_C;
extern const NSInteger CODE_CODE_B;
extern const NSInteger CODE_CODE_C;
extern const NSInteger CODE_STOP;

extern NSInteger const CODE_FNC_1;
extern NSInteger const CODE_FNC_2;
extern NSInteger const CODE_FNC_3;
extern NSInteger const CODE_FNC_4_A;
extern NSInteger const CODE_FNC_4_B;

@class ZXDecodeHints, ZXResult;

@interface ZXCode128Reader : ZXOneDReader

@end
