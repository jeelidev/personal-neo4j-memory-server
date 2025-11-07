#!/usr/bin/env node

// Test script for direct Neo4j driver connection
import neo4j from 'neo4j-driver';

console.error('Testing direct Neo4j driver connection...');
console.error('URI: bolt+s://neo4j-bolt.jeelidev.uk:443');
console.error('Username: neo4j');

try {
  // Test with different configurations

  // Configuration 1: With custom user agent
  console.error('Testing with Neo4j Browser user agent...');
  const driver1 = neo4j.driver(
    'bolt+s://neo4j-bolt.jeelidev.uk:443',
    neo4j.auth.basic('neo4j', '25448132'),
    {
      userAgent: 'Neo4jBrowser/5.0.0',
      encrypted: true,
      trust: 'TRUST_ALL_CERTIFICATES'
    }
  );

  try {
    console.error('Testing driver1 configuration...');
    const session1 = driver1.session({ database: 'system' });
    const result1 = await session1.run('RETURN 1');
    console.error('Driver1 SUCCESS! Records:', result1.records.length);
    await session1.close();
    await driver1.close();
    process.exit(0); // Success, exit early
  } catch (error1) {
    console.error('Driver1 failed:', error1.message);
    await driver1.close();
  }

  // Configuration 2: Without any extra config (original approach)
  console.error('Testing minimal configuration...');
  const driver2 = neo4j.driver(
    'bolt+s://neo4j-bolt.jeelidev.uk:443',
    neo4j.auth.basic('neo4j', '25448132')
  );

  console.error('Driver created successfully');

  const session = driver.session({ database: 'system' });
  console.error('Session created');

  const result = await session.run('RETURN 1');
  console.error('Query successful, records:', result.records.length);

  await session.close();
  await driver.close();
  console.error('Connection test successful - DIRECT DRIVER WORKS!');

} catch (error) {
  console.error('Connection test failed:', error.message);
  console.error('Full error:', error);
  console.error('Error code:', error.code);
  console.error('Error type:', error.constructor.name);
}