/**
 * Test Consistency Verification
 * Ensures all test suites follow consistent patterns and coverage
 */

const fs = require('fs');
const path = require('path');

describe('Test Consistency Verification', () => {
  const testDir = path.join(__dirname);
  const e2eDir = path.join(__dirname, '..', 'e2e');
  
  test('should have correct test file structure', () => {
    const expectedUnitTestFiles = [
      'utils.test.js',
      'index.test.js', 
      'view.test.js',
      'owasp-pentesting.test.js',
      'advanced-security.test.js'
    ];
    
    const expectedE2EFiles = [
      'secret-creation.spec.js',
      'secret-viewing.spec.js',
      'navigation.spec.js',
      'error-handling.spec.js'
    ];
    
    // Check unit test files exist
    expectedUnitTestFiles.forEach(file => {
      expect(fs.existsSync(path.join(testDir, file))).toBe(true);
    });
    
    // Check E2E test files exist
    expectedE2EFiles.forEach(file => {
      expect(fs.existsSync(path.join(e2eDir, file))).toBe(true);
    });
  });
  
  test('should have consistent test counts matching documentation', () => {
    const testCounts = {
      'utils.test.js': 20,
      'index.test.js': 19,
      'view.test.js': 22,
      'owasp-pentesting.test.js': 40,
      'advanced-security.test.js': 19
    };
    
    Object.entries(testCounts).forEach(([file, expectedCount]) => {
      const filePath = path.join(testDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const actualCount = (content.match(/test\(/g) || []).length;
      
      expect(actualCount).toBe(expectedCount);
    });
  });
  
  test('should have consistent E2E test counts', () => {
    const e2eTestCounts = {
      'secret-creation.spec.js': 15,
      'secret-viewing.spec.js': 19,
      'navigation.spec.js': 15,
      'error-handling.spec.js': 20
    };
    
    Object.entries(e2eTestCounts).forEach(([file, expectedCount]) => {
      const filePath = path.join(e2eDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const actualCount = (content.match(/test\(/g) || []).length;
      
      expect(actualCount).toBe(expectedCount);
    });
  });
  
  test('should have proper security test coverage', () => {
    const securityKeywords = [
      'XSS',
      'injection',
      'sanitiz',
      'escape',
      'malicious',
      'attack',
      'security',
      'vulnerability'
    ];
    
    const testFiles = [
      'utils.test.js',
      'index.test.js',
      'view.test.js',
      'owasp-pentesting.test.js',
      'advanced-security.test.js'
    ];
    
    testFiles.forEach(file => {
      const filePath = path.join(testDir, file);
      const content = fs.readFileSync(filePath, 'utf8').toLowerCase();
      
      const hasSecurityKeywords = securityKeywords.some(keyword => 
        content.includes(keyword)
      );
      
      expect(hasSecurityKeywords).toBe(true);
    });
  });
  
  test('should have comprehensive test descriptions', () => {
    const testFiles = fs.readdirSync(testDir).filter(f => f.endsWith('.test.js') && f !== 'test-consistency.test.js');
    
    testFiles.forEach(file => {
      const filePath = path.join(testDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      
      // Should have describe blocks
      expect(content).toMatch(/describe\(/);
      
      // Should have test blocks
      expect(content).toMatch(/test\(/);
      
      // Should have assertions
      expect(content).toMatch(/expect\(/);
    });
  });
});