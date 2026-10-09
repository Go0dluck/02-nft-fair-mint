import { readFileSync, writeFileSync } from "node:fs";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

// 1. Прочитать вход
const values: string[][] = JSON.parse(readFileSync("addresses.json", "utf8"));

// 2. Построить дерево
const tree = StandardMerkleTree.of(values, ["address"]);

// 3. Собрать proof для каждого адреса
const proofs: Record<string, string[]> = {};

for (const [i, value] of tree.entries()) {
  const address = value[0];
  proofs[address] = tree.getProof(i);
}

// 4. Сохранить результат и показать root
const output = { root: tree.root, proofs };
writeFileSync("output.json", JSON.stringify(output, null, 2));
console.log("Merkle root:", tree.root);