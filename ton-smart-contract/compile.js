const { compileFunc, compilerVersion } = require('@ton-community/func-js');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // Получаем версию компилятора
        const version = await compilerVersion();
        console.log(`Compiler version: ${JSON.stringify(version)}`);

        // Определяем путь к исходным файлам
        const srcDir = path.join(__dirname, 'src');

        // Резолвер для загрузки файлов
        const sourceResolver = (filePath) => {
            const fullPath = path.join(srcDir, filePath);
            if (!fs.existsSync(fullPath)) {
                throw new Error(`File not found: ${fullPath}`);
            }
            return fs.readFileSync(fullPath, 'utf-8');
        };

        // Компилируем контракт
        const result = await compileFunc({
            targets: ['contract.fc'], // Цель компиляции
            sources: sourceResolver,
        });

        // Проверяем результат компиляции
        if (result.status === 'error') {
            console.error('Compilation error:', result.message);
            return;
        }

        // Сохраняем результат компиляции
        const outputPath = path.join(__dirname, 'build', 'contract.fif');
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.writeFileSync(outputPath, result.fiftCode);

        console.log(`Compiled contract saved to: ${outputPath}`);
    } catch (error) {
        console.error('An error occurred:', error.message || error);
    }
}

main().catch(console.error);