## Licensed to Cloudera, Inc. under one
## or more contributor license agreements.  See the NOTICE file
## distributed with this work for additional information
## regarding copyright ownership.  Cloudera, Inc. licenses this file
## to you under the Apache License, Version 2.0 (the
## "License"); you may not use this file except in compliance
## with the License.  You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

<%!
from desktop import conf
from desktop.lib.i18n import smart_unicode
from django.utils.translation import ugettext as _
from desktop.views import _ko
%>

<%def name="config()">

  <style>
    .config-property {
      display: inline-block;
      vertical-align: top;
      margin-bottom: 20px;
      position: relative;
    }

    :not(.controls) > .config-property {
      padding-top: 10px;
    }

    .config-property-remove {
      position: absolute;
      top: -8px;
      z-index: 1000;
      right: 0;
    }

    .property-help {
      display: inline-block;
      width: 10px;
      height: 14px;
      margin-left: 7px;
      font-size: 14px;
      color: #888;
    }
  </style>

  <script type="text/html" id="property-selector-template">
    <!-- ko foreach: selectedProperties -->
    <!-- ko template: {
      name: 'property',
      data: {
        type: type(),
        label: nice_name,
        helpText: help_text,
        value: value,
        visibleObservable: $parent.visibleObservable
      }
    } --><!-- /ko -->
    <!-- /ko -->
    <div class="config-property margin-left-10" data-bind="visible: availableProperties().length > 0">
      <select data-bind="options: availableProperties, optionsText: 'nice_name', optionsCaption: 'Choose a property...', value: propertyToAdd"></select>
      <div style="display: inline-block; vertical-align: top; margin-top: 6px; margin-left: 6px;">
        <a class="inactive-action pointer" data-bind="click: addProperty">
          <i class="fa fa-plus"></i>
        </a>
      </div>
    </div>
  </script>

  <script type="text/html" id="multi-group-selector-template">
    <div class="jHueSelector" style="position: relative;" data-bind="style: { 'width': width + 'px' }">
      <div class="jHueSelectorHeader" data-bind="style: { 'width': (width-8) + 'px' }">
        <input style="float:right;position: relative; margin: 0;" type="text" placeholder="${_('Search')}" data-bind="textInput: searchQuery">
        <label><input type="checkbox" data-bind="checked: allSelected">${_('Select all')}</label>
      </div>
      <div class="jHueSelectorBody" data-bind="style: { 'height': (height - 33) + 'px' }">
        <ul>
          <!-- ko foreach: searchResultKeys -->
          <li class="selectorDivider"><strong data-bind="text: $data"></strong></li>
          <!-- ko foreach: $parent.searchResult()[$data] -->
          <li><label><input type="checkbox" class="selector" data-bind="checked: altChecked"><!-- ko text: label --><!-- /ko --></label></li>
          <!-- /ko -->
          <!-- /ko -->
        </ul>
      </div>
    </div>
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {

        function MultiGroupAlternative(alt, params, initiallyChecked) {
          var self = this;
          self.altChecked = ko.observable(initiallyChecked || false);
          self.label = params.optionsText ? alt[params.optionsText] : alt;
          var value = params.optionsValue ? alt[params.optionsValue] : alt;
          self.altChecked.subscribe(function (newValue) {
            if (newValue) {
              params.selectedOptions.push(value);
            } else {
              params.selectedOptions.remove(value);
            }
          });
        }

        function MultiGroupSelectorViewModel(params) {
          var self = this;
          self.width = params.width || 600;
          self.height = params.height || 300;

          var textAccessor = function (alt) {
            if (params.optionsText) {
              return alt[params.optionsText];
            }
            return alt;
          }

          self.searchQuery = ko.observable();

          var addToIndexedLists = function (index, key, value) {
            if (! index[key]) {
              index[key] = [];
            }
            index[key].push(value);
          }

          self.searchResult = ko.pureComputed(function () {
            if (self.searchQuery()) {
              var lowerQuery = self.searchQuery().toLowerCase();
              var result = {};
              Object.keys(self.addressBook()).forEach(function (key) {
                self.addressBook()[key].forEach(function (alt) {
                  if (alt.label.toLowerCase().indexOf(lowerQuery) !== -1) {
                    addToIndexedLists(result, key, alt);
                  }
                });
              });
              return result;
            }
            return self.addressBook();
          });

          var initiallyCheckedIndex = {};
          params.selectedOptions().forEach(function (alt) {
            initiallyCheckedIndex[alt] = true;
          });

          self.addressBook = ko.pureComputed(function () {
            var result = {}
            ko.unwrap(params.options).forEach(function (alt) {
              addToIndexedLists(result, textAccessor(alt).charAt(0).toUpperCase(), new MultiGroupAlternative(alt, params, initiallyCheckedIndex[params.optionsValue ? alt[params.optionsValue] : alt]));
            });
            Object.keys(result).forEach(function (key) {
              result[key].sort();
            })
            return result;
          });

          self.searchResultKeys = ko.pureComputed(function () {
            return Object.keys(self.searchResult()).sort();
          })

          self.allSelected = ko.observable(false);

          self.allSelected.subscribe(function (newValue) {
            self.searchResultKeys().forEach(function (key) {
              self.searchResult()[key].forEach(function (alt) {
                alt.altChecked(newValue);
              })
            })
          })
        }

        ko.components.register('multi-group-selector', {
          viewModel: MultiGroupSelectorViewModel,
          template: {element: 'multi-group-selector-template'}
        });
      }());
    }));
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {

        function PropertySelectorViewModel(params) {
          var self = this;
          var allProperties = params.properties;

          self.selectedProperties = ko.observableArray();
          self.availableProperties = ko.observableArray();
          self.propertyToAdd = ko.observable();

          var setInitialProperties = function () {
            self.selectedProperties([]);
            self.availableProperties([]);
            allProperties().forEach(function (property) {
              if (property.defaultValue && ko.mapping.toJSON(property.value) !== ko.mapping.toJSON(property.defaultValue)) {
                self.selectedProperties.push(property);
              } else {
                self.availableProperties.push(property);
              }
            });
          };

          setInitialProperties();
          self.visibleObservable = params.visibleObservable || ko.observable();

          self.visibleObservable.subscribe(function (newValue) {
            if (!newValue) {
              setInitialProperties();
            }
          });
        }

        PropertySelectorViewModel.prototype.addProperty = function () {
          var self = this;
          if (self.propertyToAdd()) {
            self.selectedProperties.push(self.propertyToAdd());
            self.availableProperties.remove(self.propertyToAdd());
            self.propertyToAdd(null);
          }
        };

        ko.components.register('property-selector', {
          viewModel: PropertySelectorViewModel,
          template: {element: 'property-selector-template'}
        });
      }());
    }));
  </script>

  <script type="text/html" id="property">
    <div data-bind="visibleOnHover: { selector: '.hover-actions' }, css: { 'config-property' : typeof inline === 'undefined' || inline, 'control-group' : typeof inline !== 'undefined' && ! inline }">
      <label class="control-label" data-bind="style: { 'width' : typeof inline === 'undefined' || inline ? '120px' : '' }">
        <!-- ko text: label --><!-- /ko --><!-- ko if: typeof helpText !== 'undefined' --><div class="property-help" data-bind="tooltip: { title: helpText(), placement: 'bottom' }"><i class="fa fa-question-circle-o"></i></div><!-- /ko -->
      </label>
      <div class="controls" style="margin-right:10px;" data-bind="style: { 'margin-left' : typeof inline === 'undefined' || inline ? '140px' : '' }">
        <!-- ko template: { name: 'property-' + type } --><!-- /ko -->
      </div>
      <!-- ko if: typeof remove !== "undefined" -->
      <div class="hover-actions config-property-remove">
        <a class="inactive-action" href="javascript:void(0)" data-bind="click: remove" title="${ _('Remove') }">
          <i class="fa fa-times"></i>
        </a>
      </div>
      <!-- /ko -->
    </div>
  </script>

  <script type="text/html" id="property-jvm">
    <div data-bind="component: { name: 'jvm-memory-input', params: { value: value } }"></div>
  </script>

  <script type="text/html" id="property-number">
    <input type="text" class="input-small" data-bind="numericTextInput: { value: value, precision: 1, allowEmpty: true }, valueUpdate:'afterkeydown', attr: { 'title': typeof title === 'undefined' ? '' : title }"/>
  </script>

  <script type="text/html" id="property-string">
    <input class="input-small" type="text" data-bind="textInput: value, valueUpdate:'afterkeydown'" />
  </script>

  <script type="text/html" id="property-boolean">
    <input class="input-small" type="checkbox" data-bind="checked: value" />
  </script>

  <script type="text/html" id="property-csv">
    <div data-bind="component: { name: 'csv-list-input', params: { value: value, placeholder: typeof placeholder === 'undefined' ? '' : placeholder } }"></div>
  </script>

  <script type="text/html" id="property-settings">
    <div data-bind="component: { name: 'key-value-list-input', params: { values: value, visibleObservable: visibleObservable } }"></div>
  </script>

  <script type="text/html" id="property-hdfs-files">
    <div data-bind="component: { name: 'hdfs-file-list-input', params: { values: value, visibleObservable: visibleObservable } }"></div>
  </script>

  <script type="text/html" id="property-csv-hdfs-files">
    <div data-bind="component: { name: 'csv-list-input', params: { value: value, inputTemplate: 'property-hdfs-file', placeholder: typeof placeholder === 'undefined' ? '' : placeholder } }"></div>
  </script>

  <div id="chooseFile" class="modal hide fade">
    <div class="modal-header">
      <a href="#" class="close" data-dismiss="modal">&times;</a>
      <h3>${_('Choose a file')}</h3>
    </div>
    <div class="modal-body">
      <div id="filechooser">
      </div>
    </div>
    <div class="modal-footer">
    </div>
  </div>

  <script type="text/html" id="property-hdfs-file">
    <div class="input-append">
      <input type="text" class="filechooser-input" data-bind="value: value, valueUpdate:'afterkeydown', filechooser: { value: value, isAddon: true}" placeholder="${ _('Path to the file, e.g. hdfs://localhost:8020/user/hue') }"/>
    </div>
  </script>

  <script type="text/html" id="property-functions">
    <div data-bind="component: { name: 'function-list-input', params: { values: value, visibleObservable: visibleObservable } }"></div>
  </script>

  <script type="text/html" id="jvm-memory-input-template">
    <input type="text" class="input-small" data-bind="numericTextInput: { value: value, precision: 0, allowEmpty: true }" /> <select class="input-mini" data-bind="options: units, value: selectedUnit" />
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {
        var JVM_MEM_PATTERN = /([0-9]+)([MG])$/;
        var UNITS = {'MB': 'M', 'GB': 'G'};

        function JvmMemoryInputViewModel(params) {
          this.valueObservable = params.value;
          this.units = Object.keys(UNITS);
          this.selectedUnit = ko.observable();
          this.value = ko.observable('');

          var match = JVM_MEM_PATTERN.exec(this.valueObservable());
          if (match && match.length === 3) {
            this.value(match[1]);
            this.selectedUnit(match[2] === 'M' ? 'MB' : 'GB');
          }

          this.value.subscribe(this.updateValueObservable, this);
          this.selectedUnit.subscribe(this.updateValueObservable, this);
        }

        JvmMemoryInputViewModel.prototype.updateValueObservable = function () {
          if (isNaN(this.value()) || this.value() === '') {
            this.valueObservable(undefined);
          } else {
            this.valueObservable(this.value() + UNITS[this.selectedUnit()]);
          }
        };

        ko.components.register('jvm-memory-input', {
          viewModel: JvmMemoryInputViewModel,
          template: { element: 'jvm-memory-input-template' }
        });
      }());
    }));
  </script>

  <script type="text/html" id="key-value-list-input-template">
    <ul data-bind="sortable: { data: values, options: { axis: 'y', containment: 'parent' }}, visible: values().length" class="unstyled">
      <li>
        <div class="input-append" style="margin-bottom: 4px">
          <input type="text" style="width: 130px" placeholder="${ _('Key') }" data-bind="textInput: key, valueUpdate: 'afterkeydown'"/>
          <input type="text" style="width: 130px" placeholder="${ _('Value') }" data-bind="textInput: value, valueUpdate: 'afterkeydown'"/>
          <span class="add-on move-widget muted"><i class="fa fa-arrows"></i></span>
          <a class="add-on muted" href="javascript: void(0);" data-bind="click: function(){ $parent.removeValue($data); }"><i class="fa fa-minus"></i></a>
        </div>
      </li>
    </ul>
    <div style="min-width: 280px; margin-top: 5px;">
      <a class="inactive-action pointer" style="padding: 3px 10px 3px 3px;;" data-bind="click: addValue">
        <i class="fa fa-plus"></i>
      </a>
    </div>
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {

        function KeyValueListInputViewModel(params) {
          var self = this;
          self.values = params.values;
          params.visibleObservable.subscribe(function (newValue) {
            if (!newValue) {
              self.values($.grep(self.values(), function (value) {
                return value.key() && value.value();
              }))
            }
          });
        }

        KeyValueListInputViewModel.prototype.addValue = function () {
          var self = this;
          var newValue = {
            key: ko.observable(''),
            value: ko.observable('')
          };
          self.values.push(newValue);
        };

        KeyValueListInputViewModel.prototype.removeValue = function (valueToRemove) {
          var self = this;
          self.values.remove(valueToRemove);
        };

        ko.components.register('key-value-list-input', {
          viewModel: KeyValueListInputViewModel,
          template: { element: 'key-value-list-input-template' }
        });
      }());
    }));
  </script>

  <script type="text/html" id="function-list-input-template">
    <ul data-bind="sortable: { data: values, options: { axis: 'y', containment: 'parent' }}, visible: values().length" class="unstyled">
      <li>
        <div class="input-append" style="margin-bottom: 4px">
          <input type="text" style="width: 110px" placeholder="${ _('Name, e.g. foo') }" data-bind="textInput: name, valueUpdate: 'afterkeydown'"/>
          <input type="text" style="width: 150px" placeholder="${ _('Class, e.g. org.hue.Bar') }" data-bind="textInput: class_name, valueUpdate: 'afterkeydown'"/>
          <span class="add-on move-widget muted"><i class="fa fa-arrows"></i></span>
          <a class="add-on muted" href="javascript: void(0);" data-bind="click: function(){ $parent.removeValue($data); }"><i class="fa fa-minus"></i></a>
        </div>
      </li>
    </ul>
    <div style="min-width: 280px; margin-top: 5px;">
      <a class="inactive-action pointer" style="padding: 3px 10px 3px 3px;;" data-bind="click: addValue">
        <i class="fa fa-plus"></i>
      </a>
    </div>
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {

        function FunctionListInputViewModel(params) {
          var self = this;
          self.values = params.values;
          params.visibleObservable.subscribe(function (newValue) {
            if (!newValue) {
              self.values($.grep(self.values(), function (value) {
                return value.name() && value.class_name();
              }))
            }
          });
        }

        FunctionListInputViewModel.prototype.addValue = function () {
          var self = this;
          var newValue = {
            name: ko.observable(''),
            class_name: ko.observable('')
          };
          self.values.push(newValue);
        };

        FunctionListInputViewModel.prototype.removeValue = function (valueToRemove) {
          var self = this;
          self.values.remove(valueToRemove);
        };

        ko.components.register('function-list-input', {
          viewModel: FunctionListInputViewModel,
          template: { element: 'function-list-input-template' }
        });
      }());
    }));
  </script>

  <script type="text/html" id="hdfs-file-list-input-template">
    <ul data-bind="sortable: { data: values, options: { axis: 'y', containment: 'parent' }}, visible: values().length" class="unstyled">
      <li>
        <div class="input-append" style="margin-bottom: 4px">
          <input type="text" class="filechooser-input" data-bind="value: path, valueUpdate:'afterkeydown', filechooser: { value: path, isAddon: true }" placeholder="${ _('Path to the file, e.g. hdfs://localhost:8020/user/hue/file.hue') }"/>
          <span class="add-on move-widget muted"><i class="fa fa-arrows"></i></span>
          <a class="add-on muted" href="javascript: void(0);" data-bind="click: function(){ $parent.removeValue($data); }"><i class="fa fa-minus"></i></a>
        </div>
      </li>
    </ul>
    <div style="min-width: 280px; margin-top: 5px;">
      <a class="inactive-action pointer" style="padding: 3px 10px 3px 3px;;" data-bind="click: addValue">
        <i class="fa fa-plus"></i>
      </a>
    </div>
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {

        var identifyType = function (path) {
          switch (path.substr(path.lastIndexOf('.') + 1).toLowerCase()) {
            case 'jar':
              return 'jar';
            case 'zip':
            case 'tar':
            case 'rar':
            case 'bz2':
            case 'gz':
            case 'tgz':
              return 'archive';
          }
          return 'file';
        };

        function HdfsFileListInputViewModel(params) {
          var self = this;
          self.values = params.values;
          $.each(self.values(), function (idx, value) {
            value.path.subscribe(function (newPath) {
              value.type(identifyType(newPath));
            });
          });
          params.visibleObservable.subscribe(function (newValue) {
            if (!newValue) {
              self.values($.grep(self.values(), function (value) {
                return value.path();
              }))
            }
          });
        }

        HdfsFileListInputViewModel.prototype.addValue = function () {
          var self = this;
          var newValue = {
            path: ko.observable(''),
            type: ko.observable('')
          };
          newValue.path.subscribe(function (newPath) {
            newValue.type(identifyType(newPath));
          });
          self.values.push(newValue);
        };

        HdfsFileListInputViewModel.prototype.removeValue = function (valueToRemove) {
          var self = this;
          self.values.remove(valueToRemove);
        };

        ko.components.register('hdfs-file-list-input', {
          viewModel: HdfsFileListInputViewModel,
          template: { element: 'hdfs-file-list-input-template' }
        });
      }());
    }));
  </script>

  <script type="text/html" id="csv-list-input-template">
    <ul data-bind="sortable: { data: values, options: { axis: 'y', containment: 'parent' }}, visible: values().length" class="unstyled">
      <li style="margin-bottom: 4px">
        <div class="input-append">
          <!-- ko ifnot: $parent.inputTemplate -->
          <input type="text" data-bind="textInput: value, valueUpdate: 'afterkeydown', attr: { placeholder: $parent.placeholder }"/>
          <!-- /ko -->
          <!-- ko template: { if: $parent.inputTemplate, name: $parent.inputTemplate } --><!-- /ko -->
          <span class="add-on move-widget muted"><i class="fa fa-arrows"></i></span>
          <a class="add-on muted" href="javascript: void(0);" data-bind="click: function(){ $parent.removeValue($data); }"><i class="fa fa-minus"></i></a>
        </div>
      </li>
    </ul>
    <div style="min-width: 280px; margin-top: 5px;">
      <a class="inactive-action pointer" style="padding: 3px 10px 3px 3px;;" data-bind="click: addValue">
        <i class="fa fa-plus"></i>
      </a>
    </div>
  </script>

  <script type="text/javascript" charset="utf-8">
    (function (factory) {
      if (typeof require === "function") {
        require(['knockout'], factory);
      } else {
        factory(ko);
      }
    }(function (ko) {
      (function () {
        function CsvListInputViewModel(params) {
          this.valueObservable = params.value;
          this.isArray = $.isArray(this.valueObservable());
          this.placeholder = params.placeholder || '';
          this.inputTemplate = params.inputTemplate || null;

          var initialValues;
          if (this.isArray) {
            initialValues = ko.mapping.toJS(this.valueObservable());
          } else {
            initialValues = this.valueObservable() != null ? this.valueObservable().split(",") : [];
          }
          for (var i = 0; i < initialValues.length; i++) {
            initialValues[i] = {value: ko.observable(initialValues[i].trim())};
            initialValues[i].value.subscribe(this.updateValueObservable, this);
          }
          this.values = ko.observableArray(initialValues);
          this.values.subscribe(this.updateValueObservable, this);
        }

        CsvListInputViewModel.prototype.addValue = function () {
          var newValue = {value: ko.observable('')};
          newValue.value.subscribe(this.updateValueObservable, this);
          this.values.push(newValue);
        };

        CsvListInputViewModel.prototype.removeValue = function (valueToRemove) {
          this.values.remove(valueToRemove);
        };

        CsvListInputViewModel.prototype.updateValueObservable = function () {
          var cleanValues = $.map(this.values(), function (item) {
            return item.value();
          });
          cleanValues = $.grep(cleanValues, function (value) {
            return value;
          });
          this.valueObservable(this.isArray ? cleanValues : cleanValues.join(','));
        };

        ko.components.register('csv-list-input', {
          viewModel: CsvListInputViewModel,
          template: { element: 'csv-list-input-template' }
        });
      }());
    }));
  </script>
</%def>