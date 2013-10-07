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

#import "ZXBitMatrix.h"
#import "ZXDataMatrixBitMatrixParser.h"
#import "ZXDataMatrixVersion.h"
#import "ZXErrors.h"

@interface ZXDataMatrixBitMatrixParser ()

@property (nonatomic, strong) ZXBitMatrix *mappingBitMatrix;
@property (nonatomic, strong) ZXBitMatrix *readMappingMatrix;

@end

@implementation ZXDataMatrixBitMatrixParser

- (id)initWithBitMatrix:(ZXBitMatrix *)bitMatrix error:(NSError **)error {
  if (self = [super init]) {
    NSInteger dimension = bitMatrix.height;
    if (dimension < 8 || dimension > 144 || (dimension & 0x01) != 0) {
      if (error) *error = FormatErrorInstance();
      return nil;
    }
    _version = [self readVersion:bitMatrix];
    if (!_version) {
      if (error) *error = FormatErrorInstance();
      return nil;
    }
    _mappingBitMatrix = [self extractDataRegion:bitMatrix];
    _readMappingMatrix = [[ZXBitMatrix alloc] initWithWidth:_mappingBitMatrix.width
                                                     height:_mappingBitMatrix.height];
  }
  
  return self;
}

/**
 * Creates the version object based on the dimension of the original bit matrix from 
 * the datamatrix code.
 * 
 * See ISO 16022:2006 Table 7 - ECC 200 symbol attributes
 */
- (ZXDataMatrixVersion *)readVersion:(ZXBitMatrix *)bitMatrix {
  NSInteger numRows = bitMatrix.height;
  NSInteger numColumns = bitMatrix.width;
  return [ZXDataMatrixVersion versionForDimensions:numRows numColumns:numColumns];
}


/**
 * Reads the bits in the {@link BitMatrix} representing the mapping matrix (No alignment patterns)
 * in the correct order in order to reconstitute the codewords bytes contained within the
 * Data Matrix Code.
 */
- (NSArray *)readCodewords {
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.version.totalCodewords];
  
  NSInteger row = 4;
  NSInteger column = 0;
  
  NSInteger numRows = self.mappingBitMatrix.height;
  NSInteger numColumns = self.mappingBitMatrix.width;
  
  BOOL corner1Read = NO;
  BOOL corner2Read = NO;
  BOOL corner3Read = NO;
  BOOL corner4Read = NO;
  
  do {
    if ((row == numRows) && (column == 0) && !corner1Read) {
      [result addObject:@([self readCorner1:numRows numColumns:numColumns])];
      row -= 2;
      column += 2;
      corner1Read = YES;
    } else if ((row == numRows - 2) && (column == 0) && ((numColumns & 0x03) != 0) && !corner2Read) {
      [result addObject:@([self readCorner2:numRows numColumns:numColumns])];
      row -= 2;
      column += 2;
      corner2Read = YES;
    } else if ((row == numRows + 4) && (column == 2) && ((numColumns & 0x07) == 0) && !corner3Read) {
      [result addObject:@([self readCorner3:numRows numColumns:numColumns])];
      row -= 2;
      column += 2;
      corner3Read = YES;
    } else if ((row == numRows - 2) && (column == 0) && ((numColumns & 0x07) == 4) && !corner4Read) {
      [result addObject:@([self readCorner4:numRows numColumns:numColumns])];
      row -= 2;
      column += 2;
      corner4Read = YES;
    } else {
      do {
        if ((row < numRows) && (column >= 0) && ![self.readMappingMatrix getX:column y:row]) {
          [result addObject:@([self readUtah:row column:column numRows:numRows numColumns:numColumns])];
        }
        row -= 2;
        column += 2;
      } while ((row >= 0) && (column < numColumns));
      row += 1;
      column += 3;
      
      do {
        if ((row >= 0) && (column < numColumns) && ![self.readMappingMatrix getX:column y:row]) {
          [result addObject:@([self readUtah:row column:column numRows:numRows numColumns:numColumns])];
        }
        row += 2;
        column -= 2;
      } while ((row < numRows) && (column >= 0));
      row += 3;
      column += 1;
    }
  } while ((row < numRows) || (column < numColumns));
  
  if ([result count] != self.version.totalCodewords) {
    return nil;
  }
  return result;
}


/**
 * Reads a bit of the mapping matrix accounting for boundary wrapping.
 */
- (BOOL)readModule:(NSInteger)row column:(NSInteger)column numRows:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  if (row < 0) {
    row += numRows;
    column += 4 - ((numRows + 4) & 0x07);
  }
  if (column < 0) {
    column += numColumns;
    row += 4 - ((numColumns + 4) & 0x07);
  }
  [self.readMappingMatrix setX:column y:row];
  return [self.mappingBitMatrix getX:column y:row];
}


/**
 * Reads the 8 bits of the standard Utah-shaped pattern.
 * 
 * See ISO 16022:2006, 5.8.1 Figure 6
 */
- (NSInteger)readUtah:(NSInteger)row column:(NSInteger)column numRows:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  NSInteger currentByte = 0;
  if ([self readModule:row - 2 column:column - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row - 2 column:column - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row - 1 column:column - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row - 1 column:column - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row - 1 column:column numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row column:column - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row column:column - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:row column:column numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  return currentByte;
}


/**
 * Reads the 8 bits of the special corner condition 1.
 * 
 * See ISO 16022:2006, Figure F.3
 */
- (NSInteger)readCorner1:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  NSInteger currentByte = 0;
  if ([self readModule:numRows - 1 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 1 column:1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 1 column:2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:2 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:3 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  return currentByte;
}


/**
 * Reads the 8 bits of the special corner condition 2.
 * 
 * See ISO 16022:2006, Figure F.4
 */
- (NSInteger)readCorner2:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  NSInteger currentByte = 0;
  if ([self readModule:numRows - 3 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 2 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 1 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 4 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 3 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  return currentByte;
}


/**
 * Reads the 8 bits of the special corner condition 3.
 * 
 * See ISO 16022:2006, Figure F.5
 */
- (NSInteger)readCorner3:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  NSInteger currentByte = 0;
  if ([self readModule:numRows - 1 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 1 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 3 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 3 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  return currentByte;
}


/**
 * Reads the 8 bits of the special corner condition 4.
 * 
 * See ISO 16022:2006, Figure F.6
 */
- (NSInteger)readCorner4:(NSInteger)numRows numColumns:(NSInteger)numColumns {
  NSInteger currentByte = 0;
  if ([self readModule:numRows - 3 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 2 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:numRows - 1 column:0 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 2 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:0 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:1 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:2 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  currentByte <<= 1;
  if ([self readModule:3 column:numColumns - 1 numRows:numRows numColumns:numColumns]) {
    currentByte |= 1;
  }
  return currentByte;
}


/**
 * Extracts the data region from a {@link BitMatrix} that contains
 * alignment patterns.
 */
- (ZXBitMatrix *)extractDataRegion:(ZXBitMatrix *)bitMatrix {
  NSInteger symbolSizeRows = self.version.symbolSizeRows;
  NSInteger symbolSizeColumns = self.version.symbolSizeColumns;
  
  if (bitMatrix.height != symbolSizeRows) {
    [NSException raise:NSInvalidArgumentException format:@"Dimension of bitMatrix must match the version size"];
  }
  
  NSInteger dataRegionSizeRows = self.version.dataRegionSizeRows;
  NSInteger dataRegionSizeColumns = self.version.dataRegionSizeColumns;
  
  NSInteger numDataRegionsRow = symbolSizeRows / dataRegionSizeRows;
  NSInteger numDataRegionsColumn = symbolSizeColumns / dataRegionSizeColumns;
  
  NSInteger sizeDataRegionRow = numDataRegionsRow * dataRegionSizeRows;
  NSInteger sizeDataRegionColumn = numDataRegionsColumn * dataRegionSizeColumns;
  
  ZXBitMatrix *bitMatrixWithoutAlignment = [[ZXBitMatrix alloc] initWithWidth:sizeDataRegionColumn height:sizeDataRegionRow];
  for (NSInteger dataRegionRow = 0; dataRegionRow < numDataRegionsRow; ++dataRegionRow) {
    NSInteger dataRegionRowOffset = dataRegionRow * dataRegionSizeRows;
    for (NSInteger dataRegionColumn = 0; dataRegionColumn < numDataRegionsColumn; ++dataRegionColumn) {
      NSInteger dataRegionColumnOffset = dataRegionColumn * dataRegionSizeColumns;
      for (NSInteger i = 0; i < dataRegionSizeRows; ++i) {
        NSInteger readRowOffset = dataRegionRow * (dataRegionSizeRows + 2) + 1 + i;
        NSInteger writeRowOffset = dataRegionRowOffset + i;
        for (NSInteger j = 0; j < dataRegionSizeColumns; ++j) {
          NSInteger readColumnOffset = dataRegionColumn * (dataRegionSizeColumns + 2) + 1 + j;
          if ([bitMatrix getX:readColumnOffset y:readRowOffset]) {
            NSInteger writeColumnOffset = dataRegionColumnOffset + j;
            [bitMatrixWithoutAlignment setX:writeColumnOffset y:writeRowOffset];
          }
        }
      }
    }
  }
  
  return bitMatrixWithoutAlignment;
}

@end
