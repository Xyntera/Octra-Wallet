// Octra Wallet — injected RFC-O-1 provider (window.octra).
//
// Implements the "Octra Provider JavaScript API" (RFC-O-1):
// https://github.com/chiefautism/octra-rfc/blob/main/rfc-o-1/rfc-o-1.md
//
// This script is injected at document start by the in-app dApp browser. It
// bridges window.octra.request(...) to the Flutter host over
// flutter_inappwebview's callHandler, and exposes an event emitter the host
// drives via evaluateJavascript("window.octra._emit(...)").
(function () {
  "use strict";
  if (window.octra && window.octra.isOctra) return; // already injected

  var PROVIDER_ID = "octra-wallet";
  var VERSION = "1.0.0";
  var listeners = {}; // event name -> [listener]

  function hostAvailable() {
    return !!(window.flutter_inappwebview &&
      typeof window.flutter_inappwebview.callHandler === "function");
  }

  // Forward a request to the Flutter host; resolve with result or throw an
  // OctraProviderError carrying { code, data } per RFC-O-1.
  function callHost(method, params) {
    if (!hostAvailable()) {
      return Promise.reject(makeError(4900, "Wallet host unavailable"));
    }
    return window.flutter_inappwebview
      .callHandler("octra", { method: method, params: params || [] })
      .then(function (resp) {
        if (resp && resp.error) {
          throw makeError(
            resp.error.code,
            resp.error.message || "Request failed",
            resp.error.data
          );
        }
        return resp ? resp.result : undefined;
      });
  }

  function makeError(code, message, data) {
    var err = new Error(message || "Octra provider error");
    err.code = typeof code === "number" ? code : 4001;
    if (data !== undefined) err.data = data;
    return err;
  }

  var provider = {
    isOctra: true,
    providerId: PROVIDER_ID,
    version: VERSION,

    request: function (args) {
      if (!args || typeof args.method !== "string") {
        return Promise.reject(makeError(4200, "Invalid request arguments"));
      }
      return callHost(args.method, args.params);
    },

    on: function (event, listener) {
      if (typeof listener === "function") {
        (listeners[event] = listeners[event] || []).push(listener);
      }
      return this;
    },

    removeListener: function (event, listener) {
      var arr = listeners[event];
      if (arr) {
        listeners[event] = arr.filter(function (l) {
          return l !== listener;
        });
      }
      return this;
    },

    removeAllListeners: function (event) {
      if (event) delete listeners[event];
      else listeners = {};
      return this;
    },

    // Internal — invoked by the wallet host to dispatch provider events.
    _emit: function (event, payload) {
      var arr = listeners[event];
      if (!arr) return;
      arr.slice().forEach(function (l) {
        try {
          l(payload);
        } catch (e) {
          /* listener errors must not break the host */
        }
      });
    },
  };

  Object.defineProperty(window, "octra", {
    value: provider,
    writable: false,
    configurable: false,
  });

  // RFC-O-1 multi-provider discovery.
  window.octraProviders = window.octraProviders || [];
  window.octraProviders.push(provider);

  try {
    window.dispatchEvent(new Event("octra#initialized"));
  } catch (e) {
    /* older webviews */
  }
})();
