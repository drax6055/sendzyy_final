// Contact Picker API Bridge for Flutter Web
window.contactPickerBridge = {
  isSupported: function () {
    try {
      return !!(
        'contacts' in navigator &&
        'ContactsManager' in window &&
        navigator.contacts &&
        typeof navigator.contacts.select === 'function'
      );
    } catch (e) {
      return false;
    }
  },

  pick: async function (multiple) {
    try {
      if (!this.isSupported()) {
        return JSON.stringify({ success: false, error: 'not_supported' });
      }
      const props = ['name', 'tel'];
      const opts = { multiple: multiple !== false };
      const rawContacts = await navigator.contacts.select(props, opts);
      if (!rawContacts || !Array.isArray(rawContacts)) {
        return JSON.stringify({ success: true, contacts: [] });
      }
      const formatted = rawContacts.map(function (c) {
        return {
          names: Array.isArray(c.name) ? c.name : (c.name ? [c.name] : []),
          tels: Array.isArray(c.tel) ? c.tel : (c.tel ? [c.tel] : []),
          emails: Array.isArray(c.email) ? c.email : (c.email ? [c.email] : [])
        };
      });
      return JSON.stringify({ success: true, contacts: formatted });
    } catch (err) {
      console.warn('[ContactPickerBridge] Error picking contacts:', err);
      // If user cancelled the dialog, standard DOMException is thrown
      return JSON.stringify({
        success: false,
        error: err.name || 'error',
        message: err.message || String(err)
      });
    }
  }
};
