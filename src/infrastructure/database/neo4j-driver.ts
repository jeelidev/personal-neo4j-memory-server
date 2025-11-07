/**
 * Neo4j Driver Management
 * Single responsibility: Neo4j driver lifecycle
 */

import neo4j, { Driver } from 'neo4j-driver';
import { getNeo4jConfig } from '../../config';

export class Neo4jDriverManager {
  private driver: Driver | null = null;
  private isConnected = false;
  private currentDatabase: string;

  constructor() {
    // Initialize with default database from environment
    const config = getNeo4jConfig();
    this.currentDatabase = config.database;
  }
  /**
   * Initialize driver connection
   * Lazy initialization - creates driver only when needed
   */
  getDriver(): Driver {
    if (!this.driver) {
      const config = getNeo4jConfig();

      // Enhanced logging for debugging Cloudflare Tunnel issues
      console.error(`[Neo4jDriverManager] Initializing driver with URI: ${config.uri}`);
      console.error(`[Neo4jDriverManager] Username: ${config.username}`);

      // Enhanced configuration for Cloudflare Tunnel compatibility
      // FIX: For bolt+s:// URLs through tunnels, use bolt:// configuration manually
      let finalUri = config.uri;
      let driverConfig: any = {
        maxConnectionLifetime: 30 * 60 * 1000, // 30 minutes
        maxConnectionPoolSize: 50,
        connectionAcquisitionTimeout: 60000, // 1 minute
        // Custom user agent for better tunnel compatibility
        userAgent: 'Neo4j-Memory-Server/3.2.0-Fixed'
      };

      // CRITICAL FIX: Convert bolt+s:// to bolt:// and manually configure encryption
      if (config.uri.startsWith('bolt+s://') && config.uri.includes('jeelidev.uk')) {
        console.error(`[Neo4jDriverManager] FIX: Converting bolt+s:// to bolt:// for tunnel compatibility`);
        finalUri = config.uri.replace('bolt+s://', 'bolt://');
        driverConfig.encrypted = true;
        driverConfig.trust = 'TRUST_ALL_CERTIFICATES';
        console.error(`[Neo4jDriverManager] Fixed URI: ${finalUri}`);
      } else if (config.uri.startsWith('bolt://') && !config.uri.includes('localhost') && !config.uri.includes('127.0.0.1')) {
        driverConfig.encrypted = true;
        driverConfig.trust = 'TRUST_ALL_CERTIFICATES';
      } else if (config.uri.startsWith('bolt://') && (config.uri.includes('localhost') || config.uri.includes('127.0.0.1'))) {
        driverConfig.encrypted = false;
      }
      // For local bolt+s://, let the URL handle encryption configuration

      console.error(`[Neo4jDriverManager] Driver config:`, JSON.stringify(driverConfig, null, 2));

      try {
        this.driver = neo4j.driver(
          finalUri,
          neo4j.auth.basic(config.username, config.password),
          driverConfig
        );
        console.error(`[Neo4jDriverManager] Driver created successfully with fixed configuration`);
      } catch (error) {
        console.error(`[Neo4jDriverManager] Failed to create driver:`, error);
        throw error;
      }
    }
    return this.driver;
  }

  /**
   * Verify driver connectivity
   * Returns promise that resolves when driver is ready
   */
  async verifyConnectivity(): Promise<void> {
    const driver = this.getDriver();
    console.error(`[Neo4jDriverManager] Verifying connectivity...`);

    // Enhanced session configuration for Cloudflare Tunnel
    const sessionConfig = {
      database: 'system',
      defaultAccessMode: neo4j.session.READ,
      // Increased timeouts for tunnel connections
      connectionTimeout: 60000,
      maxTransactionRetryTime: 30000
    };

    const session = driver.session(sessionConfig);

    try {
      console.error(`[Neo4jDriverManager] Running connectivity test query...`);
      await session.run('RETURN 1');
      this.isConnected = true;
      console.error(`[Neo4jDriverManager] Connectivity verified successfully`);
    } catch (error) {
      console.error(`[Neo4jDriverManager] Connectivity verification failed:`, error);
      // Enhanced error logging for Cloudflare Tunnel debugging
      if (error.message && error.message.includes('HTTP')) {
        console.error(`[Neo4jDriverManager] HTTP ERROR DETECTED - This suggests the tunnel is not properly configured for BOLT protocol`);
        console.error(`[Neo4jDriverManager] Suggestion: Check Cloudflare Tunnel configuration for TCP routing`);
      }
      throw error;
    } finally {
      await session.close();
    }
  }

  /**
   * Get connection status
   */
  isDriverConnected(): boolean {
    return this.isConnected;
  }

  /**
   * Close driver and cleanup resources
   */
  async close(): Promise<void> {
    if (this.driver) {
      await this.driver.close();
      this.driver = null;
      this.isConnected = false;
    }
  }

  /**
   * Get current database configuration
   */
  getCurrentDatabase(): { database: string } {
    return { database: this.currentDatabase };
  }

  /**
   * Switch to a different database
   */
  switchDatabase(databaseName: string): void {
    this.currentDatabase = databaseName;
  }
}
