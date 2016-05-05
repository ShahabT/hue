#!/usr/bin/env python
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
import sys
import datetime

LOG = logging.getLogger(__name__)


try:
  from py4j.java_gateway import JavaGateway, JavaObject
except ImportError, e:
  LOG.exception('Failed to import py4j')


def query_and_fetch(db, statement, n=None):
  data = None
  try:
    db.connect()
    curs = db.cursor()

    try:
      stmts = [stmt+";" for stmt in statement.split(";") if stmt]
      for stmt in stmts[:-1]:
        curs.execute(stmt)
      start_time = datetime.datetime.now()
      has_data = curs.execute(stmts[-1])
      end_time = datetime.datetime.now()
      if has_data:
        data = curs.fetchmany(n)
      meta = curs.description
      log = curs.log
      return data, meta, log, start_time, end_time
    finally:
      curs.close()
  finally:
    pass
    #db.close()


class Jdbc():

  def __init__(self, driver_name, url, username, password):
    if 'py4j' not in sys.modules:
      raise Exception('Required py4j module is not imported.')
    import os
    self.gateway = JavaGateway.launch_gateway(classpath=os.environ['CLASSPATH'])

    self.jdbc_driver = driver_name
    self.db_url = url
    self.username = username
    self.password = password

    self.conn = None
    self.connect()

  def connect(self):
    if self.conn is None:
      self.gateway.jvm.Class.forName(self.jdbc_driver)
      self.conn = self.gateway.jvm.java.sql.DriverManager.getConnection(self.db_url, self.username, self.password)

  def cursor(self):
    return Cursor(self.conn)

  def close(self):
    if self.conn is not None:
      self.conn.close()
      self.conn = None


def fix_type(type_name):
  if type_name[0:4]=="SQL_":
    return type_name[4:]+"_TYPE"
  if type_name.__len__()<6 or type_name[-5:]!="_TYPE":
    return type_name+"_TYPE"
  return type_name

class Cursor():
  """Similar to DB-API 2.0 Cursor interface"""

  def __init__(self, conn):
    self.conn = conn
    self.stmt = None
    self.rs = None
    self._meta = None

  def execute(self, statement):
    self.stmt = self.conn.createStatement()
    has_rs = self.stmt.execute(statement)

    if has_rs:
      self.rs = self.stmt.getResultSet()
      self._meta = self.rs.getMetaData()
    else:
      self._meta = self.stmt.getUpdateCount()

    return has_rs

  def fetchmany(self, n=None):
    res = []

    while self.rs.next() and (n is None or n > 0):
      row = []
      for c in xrange(self._meta.getColumnCount()):
        cell = self.rs.getObject(c + 1)

        if isinstance(cell, JavaObject):
          cell = str(cell) # DATETIME
        row.append(cell)

      res.append(row)
      if n is not None:
        n -= 1

    return res

  def fetchall(self, n=None):
    return self.fetchmany()

  @property
  def description(self):
    if not self.rs:
      return self._meta
    else:
      return [[
        self._meta.getColumnName(i),
        fix_type(self._meta.getColumnTypeName(i)),
        self._meta.getColumnDisplaySize(i),
        self._meta.getColumnDisplaySize(i),
        self._meta.getPrecision(i),
        self._meta.getScale(i),
        self._meta.isNullable(i),
      ] for i in xrange(1, self._meta.getColumnCount() + 1)]
  
  @property
  def log(self):
    if not self.rs:
      return "No Logs."
    try:
      return self.rs.getApproximationInfo()
    except:
      return "No Logs."

  def close(self):
    self._meta = None

    if self.rs is not None:
      self.rs.close()
      self.rs = None

    if self.stmt is not None:
      self.stmt.close()
      self.stmt = None
