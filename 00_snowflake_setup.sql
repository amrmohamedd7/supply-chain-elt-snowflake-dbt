-- =====================================================================
-- Snowflake setup: database + schema for the raw layer
-- Run this in a new SQL Worksheet in Snowsight (select all, then Run)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS SUPPLY_CHAIN;

USE DATABASE SUPPLY_CHAIN;

CREATE SCHEMA IF NOT EXISTS RAW;

-- Trial accounts already come with a default warehouse -- confirm it exists
SHOW WAREHOUSES;

-- Confirm the schema was created
SHOW SCHEMAS IN DATABASE SUPPLY_CHAIN;
