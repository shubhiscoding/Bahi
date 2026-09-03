/// Hindi UI strings — code-mixed with familiar English terms
/// Following design.md copy rules
class Strings {
  // Auth
  static const signInGoogle = 'Google से साइन इन करें';
  static const signingIn = 'साइन इन हो रहे हैं...';

  // Business creation/joining
  static const createBusiness = 'दुकान बनाएँ';
  static const joinBusiness = 'दुकान जोड़ें';
  static const businessName = 'दुकान का नाम';
  static const enterBusinessName = 'दुकान का नाम बताएँ';
  static const createButtonLabel = 'दुकान बनाएँ';
  static const inviteCode = 'कोड साझा करें';
  static const shareViaWhatsApp = 'WhatsApp से साझा करें';
  static const enterCode = 'कोड डालें';
  static const joinButtonLabel = 'दुकान जोड़ें';
  static const joiningBusiness = 'दुकान जोड़ रहे हैं...';

  // Inventory
  static const inventory = 'सामान';
  static const addItem = 'सामान जोड़ें';
  static const itemName = 'सामान का नाम';
  static const itemPrice = 'कीमत';
  static const itemQuantity = 'मात्रा';
  static const itemUnit = 'यूनिट';
  static const editItem = 'बदलें';
  static const deleteItem = 'हटाएँ';
  static const saveItem = 'सेव करें';
  static const retryVoice = 'फिर से बोलें';
  static const confirmVoice = 'सही है';
  static const cancel = 'रद्द करें';

  // Team
  static const team = 'साथी';
  static const addCoworker = 'साथी जोड़ें';
  static const removeMember = 'हटाएँ';
  static const owner = 'मालिक';
  static const member = 'सदस्य';
  static const removingMember = 'हटा रहे हैं...';
  static const leaveBusiness = 'दुकान छोड़ें';
  static const leavingBusiness = 'छोड़ रहे हैं...';

  // Settings
  static const settings = 'सेटिंग्स';
  static const checkForUpdates = 'अपडेट देखें';
  static const logout = 'लॉग आउट करें';
  static const loggingOut = 'लॉग आउट हो रहे हैं...';

  // Offline & connectivity
  static const connectToInternet = 'इंटरनेट से जुड़ें';
  static const noInternet = 'इंटरनेट नहीं है';
  static const downloadingUpdate = 'अपडेट डाउनलोड हो रहा है...';
  static const updateReady = 'अपडेट तैयार है';
  static const tapToInstall = 'इंस्टॉल करने के लिए टैप करें';

  // Empty states
  static const noItems = 'कोई सामान नहीं है';
  static const noCoworkers = 'कोई साथी नहीं है';
  static const noBusinesses = 'कोई दुकान नहीं है';

  // Errors
  static const errorOccurred = 'कुछ गलत हुआ';
  static const tryAgain = 'फिर से कोशिश करें';
  // Unified message for not-found/expired/already-used — the code is
  // ephemeral (5 min, single-use), so all three collapse to one plain
  // sentence (design.md rule 11) rather than distinguishing failure types.
  static const codeNotFound = 'यह कोड काम नहीं कर रहा। नया कोड माँगें।';

  // Edit attribution (format: "पहला-नाम द.")
  static const editedBy = 'बदला:';
  static const editedAt = 'पर';

  // Units (dropdown options)
  static const unitPiece = 'पीस';
  static const unitKg = 'किग्रा';
  static const unitLitre = 'लीटर';
  static const unitDozen = 'दर्जन';
  static const unitMetre = 'मीटर';
  static const unitBox = 'डिब्बा';
  static const unitBottle = 'बोतल';
  static const unitBag = 'बैग';

  // Stock add (Phase 8 §B)
  static const addStock = 'स्टॉक जोड़ें';
  static const addStockQuantity = 'कितना स्टॉक जोड़ें';
  static const stockAdded = 'स्टॉक जुड़ गया';

  // Buyers/Billing (Phase 8 §C-§G)
  static const bill = 'बिल';
  static const soldTo = 'बेचा';
  static const buyerName = 'खरीदार का नाम';
  static const addNewBuyer = 'नया खरीदार जोड़ें';
  static const createBuyer = 'बनाएँ';
  static const noBuyersFound = 'कोई खरीदार नहीं मिला';
  static const noBuyers = 'कोई खरीदार नहीं है';
  static const addProduct = 'सामान जोड़ें';
  static const addAnotherProduct = '+ और सामान जोड़ें';
  static const billDate = 'तारीख़';
  static const paid = 'भुगतान हो गया';
  static const unpaid = 'बाकी है';
  static const partialPayment = 'कुछ भुगतान हुआ';
  // Suffix after an amount, e.g. "₹40 भुगतान हुआ" — distinct from
  // partialPayment above (a standalone toggle-option label).
  static const partialPaymentSuffix = 'भुगतान हुआ';
  static const createBill = 'बिल बनाएँ';
  static const totalBilled = 'कुल बिल';
  static const totalPaid = 'कुल भुगतान';
  static const totalDue = 'कुल बाकी';
  static const recordPayment = 'भुगतान दर्ज करें';
  static const paymentAmount = 'कितना भुगतान हुआ';
  static const paymentsMade = 'भुगतान की सूची';
  static const billedBy = 'बिल बनाया';
  static const noBillsYet = 'अभी कोई बिल नहीं है';
  static const duplicateBuyerName = 'यह नाम पहले से है';
}
