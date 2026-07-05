import re

with open('lib/screens/ai_nutrition_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to change _buildInputView() to use a ListView for the whole content, EXCEPT the button.
# Currently it is:
# Widget _buildInputView() {
#   return Column(
#     children: [
#       Container( margin: ..., padding: ..., child: Row(...) ), // Header
#       Expanded( child: ListView( ... ) ),
#       Container( padding: ..., child: ElevatedButton(...) ) // Footer
#     ]
#   );
# }

# Let's find _buildInputView
start_idx = content.find('Widget _buildInputView() {')
end_idx = content.find('Widget _buildInputRow(int index) {', start_idx)

original_method = content[start_idx:end_idx]

# We will rewrite it manually and replace it
new_method = '''Widget _buildInputView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            children: [
              // Header Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/logoNObg.png',
                      width: 56,
                      height: 56,
                      color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catat Apa yang Kamu Makan',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tulis menu makananmu secara natural.',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Text('Menu Makanan',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text('Gram',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Rows
              ...List.generate(_rows.length, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildInputRow(i)
              )),

              const SizedBox(height: 16),
              
              // Add Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: _addRow,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppTheme.surfaceVariant,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: AppTheme.textPrimary, size: 24),
                        const SizedBox(width: 8),
                        Text('Tambah Makanan',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3400).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Text(_errorMsg!,
                        style:
                            const TextStyle(color: Color(0xFFFF3400), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Footer Button
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          color: AppTheme.surface,
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isAnalyzing)
                    const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  else
                    Image.asset(
                      'assets/icons/logoNObg.png',
                      width: 36,
                      height: 36,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 12),
                  Text(_isAnalyzing ? 'Menganalisis...' : 'Catat Makanan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  '''

content = content[:start_idx] + new_method + content[end_idx:]

# Additionally, the previous Padding of _buildInputRow might be redundant now, but we just added Padding in the generator.
# Let's check _buildInputRow to remove its outer Padding if it has one.
# Wait, _buildInputRow usually returns a Padding. If we add another Padding, it's double padding.
# Let's remove the Padding wrapper in _buildInputRow inside the list generator and keep the original _buildInputRow untouched.
new_method = new_method.replace(
    '''              ...List.generate(_rows.length, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildInputRow(i)
              )),''',
    '''              ...List.generate(_rows.length, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildInputRow(i)
              )),'''
)
# Ah wait, I need to check what _buildInputRow actually returns.

with open('lib/screens/ai_nutrition_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
