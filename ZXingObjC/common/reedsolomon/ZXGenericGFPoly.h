/**
 * Represents a polynomial whose coefficients are elements of a GF.
 * Instances of this class are immutable.
 * 
 * Much credit is due to William Rucklidge since portions of this code are an indirect
 * port of his C++ Reed-Solomon implementation.
 */

@class ZXGenericGF;

@interface ZXGenericGFPoly : NSObject

@property (nonatomic, retain, readonly) NSArray* coefficients;

- (id)initWithField:(ZXGenericGF *)field coefficients:(NSArray *)coefficients;
- (int)degree;
- (BOOL)zero;
- (int)coefficient:(int)degree;
- (int)evaluateAt:(int)a;
- (ZXGenericGFPoly *)addOrSubtract:(ZXGenericGFPoly *)other;
- (ZXGenericGFPoly *)multiply:(ZXGenericGFPoly *)other;
- (ZXGenericGFPoly *)multiplyScalar:(int)scalar;
- (ZXGenericGFPoly *)multiplyByMonomial:(int)degree coefficient:(int)coefficient;
- (NSArray *)divide:(ZXGenericGFPoly *)other;

@end