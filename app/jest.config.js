/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  setupFiles: ['<rootDir>/tests/setupEnv.js'],
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/*.spec.ts', '**/*.test.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: 'tsconfig.json',
        diagnostics: {
          ignoreCodes: [151002],
        },
      },
    ],
  },
  verbose: true,
  forceExit: true,
  clearMocks: true,
};
