const { compileFunc, compilerVersion } = require('@ton-community/func-js');
const { Cell } = require('ton');
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
            sources: sourceResolver, // Используем резолвер для загрузки файлов
        });

        // Проверяем результат компиляции
        if (result.status === 'error') {
            console.error('Compilation error:', result.message);
            return;
        }

        // Сохраняем результат компиляции
        const codeCell = Cell.fromBoc(Buffer.from(result.codeBoc, "base64"))[0];
        console.log('Compiled code (Cell):', codeCell);

        // Выводим ассемблерный код для отладки
        console.log('Fift assembly code:\n', result.fiftCode);

        // Дополнительно: Сохраняем скомпилированный код в файл
        const outputPath = path.join(__dirname, 'build', 'contract.cell');
        fs.mkdirSync(path.dirname(outputPath), { recursive: true });
        fs.writeFileSync(outputPath, codeCell.toBoc({ idx: false }));
        console.log(`Compiled contract saved to: ${outputPath}`);
    } catch (error) {
        console.error('An error occurred:', error.message || error);
    }
}

main().catch(console.error);