/*
 * Copyright 2013 ZXing authors
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

@class ZXPDF417BoundingBox, ZXPDF417DetectionResultColumn;

@interface ZXPDF417DetectionResult : NSObject

- (id)initWithBarcodeMetadata:(ZXPDF417BarcodeMetadata *)barcodeMetadata boundingBox:(ZXPDF417BoundingBox *)boundingBox;
- (NSInteger)imageStartRow:(NSInteger)barcodeColumn;
- (void)setDetectionResultColumn:(NSInteger)barcodeColumn detectionResultColumn:(ZXPDF417DetectionResultColumn *)detectionResultColumn;
- (ZXPDF417DetectionResultColumn *)detectionResultColumn:(NSInteger)barcodeColumn;
- (NSArray *)detectionResultColumns;
- (NSInteger)barcodeColumnCount;
- (NSInteger)barcodeRowCount;
- (NSInteger)barcodeECLevel;
- (ZXPDF417BoundingBox *)boundingBox;

@end
