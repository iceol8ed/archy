function hideScrollBars() {
	if (document.body) {
		var style = document.createElement('style');
		style.id = 'hide-scrollbar'
		
		style.innerHTML = `* {scrollbar-width: none !important; scrollbar-color: unset !important;} ::-webkit-scrollbar {display: none;}`;

		document.head.appendChild(style);
	} else {
		setTimeout(hideScrollBars, 100);
	}
}

hideScrollBars();
