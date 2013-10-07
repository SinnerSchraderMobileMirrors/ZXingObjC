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
 * Adapted from listings in ISO/IEC 24724 Appendix B and Appendix G.
 */

@interface ZXRSSUtils : NSObject

+ (NSArray *)rssWidths:(NSInteger)val n:(NSInteger)n elements:(NSInteger)elements maxWidth:(NSInteger)maxWidth noNarrow:(BOOL)noNarrow;
+ (NSInteger)rssValue:(NSInteger *)widths widthsLen:(NSUInteger)widthsLen maxWidth:(NSInteger)maxWidth noNarrow:(BOOL)noNarrow;
+ (NSArray *)elements:(NSArray *)eDist N:(NSInteger)N K:(NSInteger)K;

@end
