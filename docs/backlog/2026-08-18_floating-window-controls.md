# Кликабельные controls на floating-окнах

Опционально: кликабельные close/maximize/minimize на floating-окнах. Сейчас
в sway это только хоткеи ($mod+c close, $mod+f fullscreen как "maximize",
$mod+Shift+minus/$mod+minus native scratchpad как "minimize") — sway сам
виджеты на рамке не рисует. Если делать — рисовать самим (rubka уже видит
дерево через IPC), не эмулировать GTK CSD. Не блокер, чисто "было бы удобно".
