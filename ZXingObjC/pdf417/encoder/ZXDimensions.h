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
 * Data object to specify the minimum and maximum number of rows and columns for a PDF417 barcode.
 */
@interface ZXDimensions : NSObject

@property (nonatomic, assign) NSInteger minCols;
@property (nonatomic, assign) NSInteger maxCols;
@property (nonatomic, assign) NSInteger minRows;
@property (nonatomic, assign) NSInteger maxRows;

- (id)initWithMinCols:(NSInteger)minCols maxCols:(NSInteger)maxCols minRows:(NSInteger)minRows maxRows:(NSInteger)maxRows;

@end
